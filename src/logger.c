#include <stdbool.h>
#include <stdio.h>
#include <time.h>

#include "types.h"

const char *LEVELSTRINGS[4] = {"INFO", "DEBUG", "WARN", "FATAL"};

bool RUNNING = true;

void logState(LogLevel ll, const char *msg) {
    time_t now;
    time(&now);
    struct tm *timeStruct;
    char timeStr[9];
    timeStruct = localtime(&now);
    strftime(timeStr, sizeof(timeStr), "%H:%M:%S", timeStruct);
    printf("%s [%s]: %s\n", timeStr, LEVELSTRINGS[ll], msg);

    if ((ll == FATAL) && RUNNING) {
        printf("Emulator has crashed, exiting shortly.\n");
        RUNNING = false;
    }
}
