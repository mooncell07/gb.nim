#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "SDL2/SDL.h"
#include "fifo.h"

typedef struct {
    uint8_t fetcherState;
    uint8_t spriteState;

    uint16_t internalX;
    uint8_t tileNum;
    uint16_t tileDataAddr;
    uint8_t tileLo;
    uint8_t tileSlice[8];

    bool firstInstance;
    bool isWindowVisible;
    bool tickingSprite;
    uint8_t staticLine;

    uint16_t spriteDataAddr;
    uint8_t spriteLo;
    uint8_t spriteSlice[8];
    Sprite currSprite;

} Fetcher;

extern Fetcher f;
extern PixelFIFO tFIFO;
extern PixelFIFO sFIFO;
extern SpriteBuffer sprites;

uint8_t getColorIndex(uint8_t code, bool obj, bool palette1);
SDL_Color searchColor(uint8_t colorIndex);
void tileTick(Fetcher *f);
void spriteTick(Fetcher *f);
void fetchMain(Fetcher *f, uint16_t xPos);
void fetchBackground(Fetcher *f);
void fetchWindow(Fetcher *f);
void clearSpriteFetcher();
