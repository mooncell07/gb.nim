#pragma once
#include <SDL2/SDL.h>
#include <stdbool.h>

void destroyLCD();
bool initLCD();
void drawPixel(SDL_Color col);
void renderFrame();
