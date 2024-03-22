import sdl2

const
    WIDTH = 160
    HEIGHT = 144

var
    window: WindowPtr
    renderer: RendererPtr
    texture: TexturePtr

    buffer: array[WIDTH * HEIGHT, uint32]
    index: int

    pixelFmt: ptr PixelFormat


proc init*(scale: int = 3): void =
    window = createWindow(
            "gb.nim", SDL_WINDOWPOS_CENTERED,
            SDL_WINDOWPOS_CENTERED,
            (WIDTH * scale).cint,
            (HEIGHT * scale).cint,
            SDL_WINDOW_SHOWN
        )

    renderer = createRenderer(window, -1, 1)
    texture = createTexture(renderer, SDL_PIXELFORMAT_ABGR8888,
            SDL_TEXTUREACCESS_STREAMING, WIDTH.cint, HEIGHT.cint)
    pixelFmt = allocFormat(window.getPixelFormat())

proc drawPixel*(col: Color): void =
    buffer[index] = mapRGBA(pixelFmt, col.r, col.g, col.b, col.a)
    index += 1

proc renderFrame*(): void =
    index = 0
    texture.updateTexture(nil, addr buffer, (WIDTH * 4).cint)
    renderer.copy(texture, nil, nil)
    renderer.present()

proc destroy*(): void =
    renderer.destroy()
    texture.destroy()
    pixelFmt.destroy()
    window.destroy()
