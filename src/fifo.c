#include "fifo.h"

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "logger.h"
#include "types.h"

Pixel EMPTYPIXEL = {0};
Sprite EMPTYSPRITE = {0};

inline Pixel _popPixelFIFO(PixelFIFO *buffer) {
    Pixel *p = &EMPTYPIXEL;
    _popItem(buffer, p);
    return *p;
}

inline Pixel _getPixelAt(PixelFIFO *buffer, int idx) {
    Pixel *p = &EMPTYPIXEL;
    _getItemAt(buffer, p, idx);
    return *p;
}

inline Sprite _getSpriteAt(SpriteBuffer *buffer, int idx) {
    Sprite *s = &EMPTYSPRITE;
    _getItemAt(buffer, s, idx);
    return *s;
}

inline Sprite _popSpriteBuffer(SpriteBuffer *buffer) {
    Sprite *s = &EMPTYSPRITE;
    _popItem(buffer, s);
    return *s;
}

inline int FIFOLen(FIFOBase *base) { return base->ptr; }

inline void clearFIFO(FIFOBase *base) {
    base->head = 0;
    base->tail = 0;
    base->ptr = 0;
}
