#import "Basic";
#import "SDL";
#import "String";
// #import "Vulkan";
#import "Windows";

#import  "osor_vulkan";

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

    vulkan_library := LoadLibraryA("vulkan-1.dll");
    load_vulkan_loader_procedures(vulkan_library , GetProcAddress);

    {
        instanceExtensions : [..]string;    
        array_add(*instanceExtensions, VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME);        

        instanceLayers : [..]string;
        array_add(*instanceLayers, "VK_LAYER_KHRONOS_validation"); // only in debug
        
        vulkanInstance := vkal_create_instance_sdl(window, instanceExtensions, instanceLayers);        
        load_vulkan_instance_procedures(vulkanInstance);
    }

    deviceExtensions : [..]string;
    array_add(*deviceExtensions, VK_KHR_SWAPCHAIN_EXTENSION_NAME);
    array_add(*deviceExtensions, VK_KHR_MAINTENANCE3_EXTENSION_NAME);
    // array_add(*deviceExtensions, "DAYUM");
    physicalDevices : [..]VkalPhysicalDevice = vkal_find_suitable_devices(deviceExtensions);

    assert(physicalDevices.count > 0);
    for physicalDevices {
        print("Physical Device %: %\n", it_index, to_string(it.properties.deviceName.data));
    }

    vkal_select_physical_device(physicalDevices[0]); // Just take the first in the list, because we know there is one.
    
    wantedFeatures : VkalWantedFeatures;
    logicalDevice := vkal_create_logical_device(deviceExtensions, .[VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES, VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES]);
    // load_vulkan_device_procedures(logicalDevice);
    
    // SDL_Delay(2000);

}