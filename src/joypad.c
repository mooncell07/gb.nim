#include "joypad.h"

#include <SDL2/SDL.h>
#include <stdint.h>

#include "utils.h"

JoypadState js = {0};

#define toggleBit(pos) setBit(js.keyState, pos);
#define resetBit(pos) clearBit(js.keyState, pos);

void unsetKey(int key) {
    switch (key) {
        case SDLK_e:
            resetBit(0);
            break;
        case SDLK_q:
            resetBit(1);
            break;
        case SDLK_LSHIFT:
            resetBit(2);
            break;
        case SDLK_z:
            resetBit(3);
            break;

        case SDLK_d:
            resetBit(4);
            break;
        case SDLK_a:
            resetBit(5);
            break;
        case SDLK_w:
            resetBit(6);
            break;
        case SDLK_s:
            resetBit(7);
            break;
        default:
            break;
    }
}

void setKey(int key) {
    switch (key) {
        case SDLK_e:
            toggleBit(0);
            break;
        case SDLK_q:
            toggleBit(1);
            break;
        case SDLK_LSHIFT:
            toggleBit(2);
            break;
        case SDLK_z:
            toggleBit(3);
            break;

        case SDLK_d:
            toggleBit(4);
            break;
        case SDLK_a:
            toggleBit(5);
            break;
        case SDLK_w:
            toggleBit(6);
            break;
        case SDLK_s:
            toggleBit(7);
            break;
        default:
            break;
    }
}

void setKeyMask() {
    uint8_t controlBits = BEXTR(js.P1, 4, 5);
    js.keyMask = 0xCF;
    switch (controlBits) {
        case 0b00:
            break;
        case 0b01: {
            uint8_t keyIndex = __builtin_ffs(BEXTR(js.keyState, 0, 3));
            if (keyIndex > 0) {
                uint8_t finalKeyIndex = keyIndex - 1;
                js.fallingEdge = BT(js.keyMask, finalKeyIndex);
                clearBit(js.keyMask, finalKeyIndex);
            }

            break;
        }
        case 0b10: {
            uint8_t keyIndex = __builtin_ffs(BEXTR(js.keyState, 4, 7));
            if (keyIndex > 0) {
                uint8_t finalKeyIndex = keyIndex - 1;
                js.fallingEdge = BT(js.keyMask, finalKeyIndex);
                clearBit(js.keyMask, finalKeyIndex);
            }
            break;
        }
        case 0b11:
            js.keyMask = 0xFF;
            break;
    }
}
