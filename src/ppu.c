#include "ppu.h"

#include <SDL2/SDL.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "fetcher.h"
#include "fifo.h"
#include "io.h"
#include "lcd.h"
#include "logger.h"
#include "types.h"
#include "utils.h"
#include "vbus.h"

PPUStateType state;
int dots;
bool intLineUp;
bool incrWLY;
bool windowInit = true;
bool windowTrigger;
uint8_t dropPixels;

void sortSprites() {
    // An implementation of isort3.
    int i = 1;
    while (i < FIFOLen(&sprites.base)) {
        Sprite next = getEntryAt(sprites, &sprites, i);
        int j = i;
        while (j > 0 && getEntryAt(sprites, &sprites, j - 1).x > next.x) {
            setEntryAt(sprites, j, getEntryAt(sprites, &sprites, j - 1));
            j = j - 1;
        }
        setEntryAt(sprites, j, next);
        i = i + 1;
    }
}

void searchSprites() {
    for (int i = 0; i < 40; i++) {
        if (FIFOLen(&sprites.base) == 10) {
            break;
        }

        uint8_t spriteY = oam[i * 4];
        uint8_t spriteX = oam[i * 4 + 1];
        uint8_t tileNum = oam[i * 4 + 2];
        uint8_t flags = oam[i * 4 + 3];
        uint8_t spriteHeight = 8;

        if (getLCDC(OBJSIZE)) {
            spriteHeight = 16;
        }

        if (((ioRegs.LY + 16) >= spriteY) &&
            ((ioRegs.LY + 16) < (spriteY + spriteHeight)) && (spriteX > 0)) {
            Sprite spr = {spriteX, spriteY, tileNum, flags, spriteHeight};
            pushEntry(sprites, spr);
        }
    }
    sortSprites();
}

void isWindowEnabled() {
    if (ioRegs.LY == ioRegs.WY) {
        windowTrigger = true;
    }
    uint8_t saturatedWX = ioRegs.WX - 7;
    if (ioRegs.WX <= 6) {
        saturatedWX = 0;
    }
    f.isWindowVisible = getLCDC(WINEN) && windowTrigger &&
                        (ioRegs.LX >= saturatedWX) &&
                        BOUND(ioRegs.WY, 0, 143) && (saturatedWX <= 159);
}

SDL_Color getTileColor(uint8_t colorCode) {
    return searchColor(getLCDC(BGANDWINEN) ? colorCode
                                           : BEXTR(ioRegs.BGP, 0, 1));
}

bool checkStatInt(uint8_t v) { return BT(ioRegs.STAT, v); }

void sendStatInt() {
    bool oldState = intLineUp;
    intLineUp = true;

    if (!oldState && intLineUp) {
        sendIntReq(INTSTAT);
    }
}

void handleCoincidence(bool quirk) {
    uint8_t qLY = ioRegs.LY;
    if (quirk) qLY = 0;

    if (qLY == ioRegs.LYC) {
        setBit(ioRegs.STAT, 2);
        checkStatInt(6) ? sendStatInt() : clearBit(ioRegs.STAT, 2);
    }
}

void nextLine() {
    ioRegs.LY++;
    if (incrWLY) ioRegs.WLY++;
    handleCoincidence(false);
}

void switchMode(PPUStateType t) {
    clearBit(ioRegs.STAT, 0);
    clearBit(ioRegs.STAT, 1);
    ioRegs.STAT = ioRegs.STAT | t;
    state = t;

    if (state != PIXELTRANSFER && checkStatInt(t + 3)) sendStatInt();
}

void ppuTick() {
    if (!getLCDC(LCDPPUEN)) {
        switchMode(HBLANK);
        ioRegs.LY = 0;
        return;
    }

    dots++;

    switch (state) {
        case OAMSEARCH:
            if (dots == 80) {
                fetchBackground(&f);
                dropPixels = ioRegs.SCX % 8;
                searchSprites();
                switchMode(PIXELTRANSFER);
            }
            break;

        case PIXELTRANSFER:
            if (f.tickingSprite) {
                spriteTick(&f);
            } else {
                if (FIFOLen(&sprites.base) != 0) {
                    Sprite spr = getEntryAt(sprites, &sprites, 0);
                    if (spr.x <= (ioRegs.LX + 8)) {
                        f.currSprite = spr;
                        f.tickingSprite = true;
                        spriteTick(&f);
                    }
                }
            }

            isWindowEnabled();

            if (f.isWindowVisible) {
                incrWLY = true;
                if (windowInit) {
                    fetchWindow(&f);
                    windowInit = false;
                    if (ioRegs.WX <= 6 && ioRegs.WX > 0) {
                        dropPixels = 7 - ioRegs.WX;
                    }
                    return;
                }
            }
            if (!f.tickingSprite) {
                tileTick(&f);
            }
            if ((FIFOLen(&tFIFO.base) > 0) && !f.tickingSprite) {
                Pixel tilePixel = popEntry(tFIFO, &tFIFO);

                if (dropPixels > 0) {
                    dropPixels -= 1;
                    return;
                }

                uint8_t tilePixelColorIndex =
                    getColorIndex(tilePixel.colorCode, false, false);
                SDL_Color tilePixelColor = getTileColor(tilePixelColorIndex);

                SDL_Color finalColor;

                if (FIFOLen(&sFIFO.base) > 0) {
                    Pixel spritePixel = popEntry(sFIFO, &sFIFO);
                    uint8_t spritePixelColorIndex = getColorIndex(
                        spritePixel.colorCode, true, spritePixel.palette1);
                    SDL_Color spritePixelColor =
                        searchColor(spritePixelColorIndex);

                    if ((spritePixel.colorCode == 0) ||
                        (spritePixel.priority && (tilePixel.colorCode != 0))) {
                        finalColor = tilePixelColor;
                    } else {
                        finalColor =
                            getLCDC(OBJEN) ? spritePixelColor : tilePixelColor;
                    }
                } else
                    finalColor = tilePixelColor;

                drawPixel(finalColor);
                ioRegs.LX++;
            }

            if (ioRegs.LX == 160) {
                int dotsConsumed = dots - 80;
                if ((dotsConsumed < 172) || (dotsConsumed > 289)) {
                    char dotStr[35];
                    snprintf(dotStr, sizeof(dotStr), "Mode 3 Under/Overrun: %d",
                             dotsConsumed);
                    logState(DEBUG, dotStr);
                }
                switchMode(HBLANK);
            }
            break;

        case HBLANK:
            if (dots == 456) {
                nextLine();

                f.firstInstance = true;
                windowInit = true;
                intLineUp = false;
                incrWLY = false;

                ioRegs.LX = 0;
                dots = 0;

                clearSpriteFetcher();

                if (ioRegs.LY > 143) {
                    renderFrame();
                    switchMode(VBLANK);
                    sendIntReq(INTVBLANK);
                } else {
                    switchMode(OAMSEARCH);
                }
            }
            break;

        case VBLANK:
            // Line 153 Quirk: LY==LYC is checked at the start of 153rd scanline
            // after a 1 M-cycle delay, at this point LYC is already 0 and
            // expects LY to be 0 as well, since the ppu is still ticking the
            // 153rd scanline, directly writing 0 to LY causes a crash so, we
            // instead match LYC to a "virtual" LY value of 0.
            if ((ioRegs.LY == 153) && (dots == 4)) {
                handleCoincidence(true);
            }

            if (dots > 456) {
                dots = 0;
                nextLine();

                if (ioRegs.LY > 153) {
                    ioRegs.LY = 0;
                    ioRegs.WLY = 0;
                    windowTrigger = false;
                    switchMode(OAMSEARCH);
                }
            }
            break;

        default:
            logState(FATAL, "Invalid PPU state.");
            break;
    }
}
