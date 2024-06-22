#include "fetcher.h"

#include <SDL2/SDL.h>
#include <stdbool.h>
#include <stdint.h>

#include "fifo.h"
#include "io.h"
#include "logger.h"
#include "utils.h"
#include "vbus.h"

const SDL_Color DEFAULT_PALETTE[4] = {
    {0xFF, 0xF6, 0xD3, 0xFF},  // 00 - WHITE
    {0xF9, 0xA8, 0x75, 0xFF},  // 01 - LIGHT GRAY
    {0xEB, 0x6B, 0x6F, 0xFF},  // 10 - DARK GRAY
    {0x7C, 0x3F, 0x58, 0xFF}   // 11 - BLACK
};

Fetcher f = {0};
PixelFIFO tFIFO = {{.maxSize = 8}, {{0}}};
PixelFIFO sFIFO = {{.maxSize = 8}, {{0}}};
SpriteBuffer sprites = {{.maxSize = 10}, {{0}}};

uint16_t getTileDataOffset(uint8_t tileNum) {
    if (getLCDC(BGANDWINTILEDATAAREA)) {
        return getTileDataBase() + ((uint16_t)tileNum * 16);
    }
    return getTileDataBase() + ((uint16_t)((int8_t)tileNum) * 16);
}

uint16_t getTileRow(Fetcher *f) {
    if (!f->isWindowVisible) {
        return ((uint16_t)(f->staticLine % 8) * 2);
    }
    return (uint16_t)(ioRegs.WLY % 8) * 2;
}

uint16_t internalY(Fetcher *f) {
    if (!f->isWindowVisible) {
        return ((uint16_t)(((ioRegs.LY + ioRegs.SCY) & 0xFF) / 8) * 32);
    }
    return (uint16_t)(ioRegs.WLY / 8.0) * 32;
}

uint8_t getColorIndex(uint8_t code, bool obj, bool palette1) {
    int index = (int)code * 2;
    uint8_t palette;
    if (obj) {
        palette = palette1 ? ioRegs.OBP1 : ioRegs.OBP0;
    } else {
        palette = ioRegs.BGP;
    }
    return BEXTR(palette, index, index + 1);
}

SDL_Color searchColor(uint8_t colorIndex) {
    return DEFAULT_PALETTE[colorIndex];
}

void fetchPixelSlice(Fetcher *f, uint8_t lo, uint8_t hi, bool isSprite) {
    int revX = 0;
    uint8_t cc = 0;
    uint8_t *slice = isSprite ? f->spriteSlice : f->tileSlice;

    for (int x = 7; x >= 0; x--) {
        cc = (BT(hi, x) << 1) | BT(lo, x);
        slice[revX] = cc;
        revX++;
    }
}

void tileTick(Fetcher *f) {
    switch (f->fetcherState) {
        case 0:
            f->fetcherState = 1;
            break;

        case 1:
            f->staticLine = ioRegs.LY + ioRegs.SCY;
            f->tileNum =
                ppuReadByte(getTileMapBase(f->isWindowVisible) +
                                ((f->internalX + internalY(f)) & 0x3FF),
                            false);
            f->fetcherState = 2;
            break;

        case 2:
            f->fetcherState = 3;
            break;

        case 3:
            f->tileDataAddr = getTileDataOffset(f->tileNum) + getTileRow(f);
            f->tileLo = ppuReadByte(f->tileDataAddr, false);
            f->fetcherState = 4;
            break;

        case 4:
            f->fetcherState = 5;
            break;

        case 5:
            fetchPixelSlice(f, f->tileLo,
                            ppuReadByte(f->tileDataAddr + 1, false), false);
            f->fetcherState = 6;
            if (f->firstInstance) {
                f->fetcherState = 0;
                f->firstInstance = false;
                return;
            }
            break;

        case 6:
            if (FIFOLen(&tFIFO.base) != 0) return;

            for (int i = 0; i < 8; i++) {
                Pixel px = {f->tileSlice[i], false, false};
                pushEntry(tFIFO, px);
            }
            f->internalX = (f->internalX + 1) % 32;
            f->fetcherState = 0;
            break;

        default:
            logState(FATAL, "Invalid Tile Fetcher state.");
            break;
    }
}

void flipX(Fetcher *f) {
    int i = 7, j = 0;
    while (i > j) {
        uint8_t cc = f->spriteSlice[i];
        f->spriteSlice[i] = f->spriteSlice[j];
        f->spriteSlice[j] = cc;
        i--;
        j++;
    }
}

void spriteTick(Fetcher *f) {
    switch (f->spriteState) {
        case 0:
            // Ignore LSb of tall sprites.
            if (f->currSprite.height == 16) f->currSprite.tileNum &= 0xFE;

            uint16_t yOff =
                (uint16_t)ioRegs.LY - (uint16_t)f->currSprite.y + 16;

            // Vertical flip.
            if (BT(f->currSprite.flags, 6))
                yOff = f->currSprite.height - 1 - yOff;

            f->spriteDataAddr =
                0x8000 + ((uint16_t)f->currSprite.tileNum * 16) + (yOff * 2);
            f->spriteLo = ppuReadByte(f->spriteDataAddr, false);
            f->spriteState = 1;
            break;

        case 1:
            fetchPixelSlice(f, f->spriteLo,
                            ppuReadByte(f->spriteDataAddr + 1, false), true);
            f->spriteState = 2;
            break;
        case 2:
            // Horizontal flip.
            if (BT(f->currSprite.flags, 5)) flipX(f);

            // If the Sprite FIFO already has some residual pixels left then we
            // have to mix both the new and the residual pixel at position I
            // using a transparency check.
            uint8_t residualAmount = FIFOLen(&sFIFO.base);

            for (int i = 0; i < 8; i++) {
                uint8_t cc = f->spriteSlice[i];
                Pixel px = {cc, BT(f->currSprite.flags, 4),
                            BT(f->currSprite.flags, 7)};

                if (residualAmount >= (i + 1)) {
                    Pixel residualPixel = getEntryAt(sFIFO, &sFIFO, i);

                    if ((residualPixel.colorCode == 0) && cc != 0) {
                        setEntryAt(sFIFO, i, px);
                    }
                } else {
                    pushEntry(sFIFO, px);
                }
            }

            popEntry(sprites, &sprites);

            f->spriteState = 0;
            f->tickingSprite = false;
            break;

        default:
            logState(FATAL, "Invalid Tile Fetcher state.");
            break;
    }
}

void fetchMain(Fetcher *f, uint16_t xPos) {
    f->fetcherState = 0;
    f->internalX = xPos;
    clearFIFO(&tFIFO.base);
}

void fetchBackground(Fetcher *f) {
    fetchMain(f, ((uint16_t)(ioRegs.SCX / 8) & 0x1F));
}

void fetchWindow(Fetcher *f) {
    uint8_t saturatedWX = ioRegs.WX - 7;
    if (ioRegs.WX <= 6 && ioRegs.WX > 0) {
        saturatedWX = ioRegs.WX;
    }
    fetchMain(f, (uint16_t)((ioRegs.LX - saturatedWX) / 8) & 0x1F);
}

void clearSpriteFetcher() {
    clearFIFO(&sprites.base);
    clearFIFO(&sFIFO.base);
}
