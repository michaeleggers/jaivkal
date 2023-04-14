#import "Basic";
#import "SDL";
#import "String";
#import "Vulkan";

//#import,dir "osor_vulkan";
#import,dir "vkal";



/* Evil globals */
window : *SDL_Window;

/* Constants */
WINDOW_WIDTH  :: 800;
WINDOW_HEIGHT :: 600;

init_window :: () {
    SDL_Init(SDL_INIT_EVERYTHING);

    window = SDL_CreateWindow(
        "Hello Vulkan SDL",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        WINDOW_WIDTH, WINDOW_HEIGHT,
        SDL_WINDOW_VULKAN | SDL_WINDOW_RESIZABLE
    );

    if window == null {
        print("Could not create SDL window: %\n", to_string(SDL_GetError()));
        return;
    }

}

main :: () {
    init_window();

    instanceExtensions : [..]string;    
    array_add(*instanceExtensions, VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME);    
    instanceLayers : [..]string;
    array_add(*instanceLayers, "VK_LAYER_KHRONOS_validation"); // only in debug
    
    vkal_create_instance_sdl(window, instanceExtensions, instanceLayers);
    
    // /SDL_Delay(2000);

}