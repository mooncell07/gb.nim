
#include "lcd.h"

#include <SDL2/SDL.h>
#include <stdint.h>

#include "joypad.h"
#include "logger.h"
#include "types.h"

const int WIDTH = 160;
const int HEIGHT = 144;

SDL_Window *window;
SDL_Renderer *renderer;
SDL_Texture *texture;
SDL_Event userEvent;
uint32_t *pixelBuffer;
SDL_PixelFormat *pixelFmt;
int bufferIndex;

void destroyLCD() {
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_DestroyTexture(texture);
    if (pixelBuffer != NULL) {
        free(pixelBuffer);
        pixelBuffer = NULL;
    }

    SDL_Quit();
}

void handleInput() {
    while (SDL_PollEvent(&userEvent)) {
        if (userEvent.type == SDL_KEYDOWN) {
            setKey(userEvent.key.keysym.sym);
        }
        if (userEvent.type == SDL_KEYUP) {
            unsetKey(userEvent.key.keysym.sym);
        }
        if (userEvent.type == SDL_QUIT) {
            RUNNING = false;
        }
    }
}

bool initLCD() {
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        logState(FATAL, "Failed to initialize SDL.");
        return false;
    }

    pixelBuffer = (uint32_t *)malloc(WIDTH * HEIGHT * sizeof(uint32_t));

    if (pixelBuffer == NULL) {
        logState(FATAL, "Failed to allocate memory for pixel buffer.");
        return false;
    }

    window =
        SDL_CreateWindow("gb.c", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                         (WIDTH * 3), (HEIGHT * 3), SDL_WINDOW_SHOWN);

    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_PRESENTVSYNC);
    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                                SDL_TEXTUREACCESS_STREAMING, WIDTH, HEIGHT);
    pixelFmt = SDL_AllocFormat(SDL_GetWindowPixelFormat(window));
    SDL_RenderSetLogicalSize(renderer, WIDTH, HEIGHT);

    return true;
}

void drawPixel(SDL_Color col) {
    pixelBuffer[bufferIndex] =
        SDL_MapRGBA(pixelFmt, col.r, col.g, col.b, col.a);
    bufferIndex += 1;
}

void renderFrame() {
    handleInput();
    bufferIndex = 0;
    SDL_UpdateTexture(texture, NULL, pixelBuffer, (WIDTH * 4));
    SDL_RenderCopy(renderer, texture, NULL, NULL);
    SDL_RenderPresent(renderer);
}
