#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include "logger.h"

typedef struct {
    uint8_t colorCode;
    bool palette1;
    bool priority;
} Pixel;

typedef struct {
    uint8_t x;
    uint8_t y;
    uint8_t tileNum;
    uint8_t flags;
    uint16_t height;
} Sprite;

typedef struct {
    int head;
    int tail;
    int ptr;
    int maxSize;
} FIFOBase;

typedef struct {
    FIFOBase base;
    Pixel entries[8];
} PixelFIFO;

typedef struct {
    FIFOBase base;
    Sprite entries[10];
} SpriteBuffer;

#define _GETITEM(buffer) buffer->entries[buffer->base.head]

#define _popItem(buffer, container)                                         \
    if (buffer->base.ptr == 0) {                                            \
        logState(FATAL, "(_popItem) FIFO is empty.");                       \
    } else {                                                                \
        container = &_GETITEM(buffer);                                      \
        buffer->base.head = (buffer->base.head + 1) % buffer->base.maxSize; \
        buffer->base.ptr--;                                                 \
    }

#define _getItemAt(buffer, container, idx)                                    \
    if (idx < 0 || idx >= buffer->base.maxSize) {                             \
        logState(FATAL, "(_getItemAt) Index is out of bounds.");              \
    } else {                                                                  \
        container =                                                           \
            &buffer                                                           \
                 ->entries[(buffer->base.head + idx) % buffer->base.maxSize]; \
    }

#define setEntryAt(buffer, idx, entry)                                   \
    if (idx < 0 || idx >= buffer.base.maxSize) {                         \
        logState(DEBUG, "(setEntryAt) Index is out of bounds.");         \
    } else {                                                             \
        buffer.entries[(buffer.base.head + idx) % buffer.base.maxSize] = \
            entry;                                                       \
    }

#define pushEntry(buffer, entry)                                         \
    if (buffer.base.ptr >= buffer.base.maxSize) {                        \
        logState(DEBUG, "(pushEntry) FIFO is FULL");                     \
    } else {                                                             \
        buffer.entries[buffer.base.tail] = entry;                        \
        buffer.base.tail = (buffer.base.tail + 1) % buffer.base.maxSize; \
        buffer.base.ptr++;                                               \
    }

Pixel _popPixelFIFO(PixelFIFO *buffer);
Pixel _getPixelAt(PixelFIFO *buffer, int idx);
Sprite _popSpriteBuffer(SpriteBuffer *buffer);
Sprite _getSpriteAt(SpriteBuffer *buffer, int idx);
int FIFOLen(FIFOBase *base);
void clearFIFO(FIFOBase *base);

#define getEntryAt(T, buffer, idx)       \
    _Generic((T), PixelFIFO              \
             : _getPixelAt, SpriteBuffer \
             : _getSpriteAt)(buffer, idx)

#define popEntry(T, buffer)                \
    _Generic((T), PixelFIFO                \
             : _popPixelFIFO, SpriteBuffer \
             : _popSpriteBuffer)(buffer)
