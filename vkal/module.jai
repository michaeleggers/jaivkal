#import "Basic";
#import "SDL";
#import "Vulkan";

//#import,dir "../osor_vulkan";

VkalInfo :: struct {
    window : *SDL_Window;

    instance_extension_count : u32;
    instance_extensions : [..]VkExtensionProperties;

    instance_layer_count : u32;
    instance_layers : [..]VkLayerProperties;
}

vkal_info : VkalInfo;

vkal_create_instance_sdl :: (window : *SDL_Window, instance_extensions : []string, instance_layers : []string) {
    vkal_info.window = window;
    
    app_info := VkApplicationInfo.{
        sType = .VK_STRUCTURE_TYPE_APPLICATION_INFO ,
        pApplicationName = "vulkan application",
        applicationVersion = 0x000001,
        pEngineName = "cool vulkan rendering engine!",
        engineVersion = 0x000001,
        apiVersion = VK_API_VERSION_1_3
    };

    create_info := VkInstanceCreateInfo.{
        sType = .VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        pApplicationInfo = *app_info
    };
    
    // Check instance extensions
    {
        // See what is available on this machine
        vkEnumerateInstanceExtensionProperties(null, *vkal_info.instance_extension_count, null);
        print("Available Instance Extension:\n");
        print("-----------------------------\n");
        // temp_instance_extensions := NewArray(vkal_info.instance_extension_count, VkExtensionProperties);
        // defer free(temp_instance_extensions.data);
        array_resize(*vkal_info.instance_extensions, vkal_info.instance_extension_count);
        vkEnumerateInstanceExtensionProperties(null, *vkal_info.instance_extension_count, vkal_info.instance_extensions.data);
        for vkal_info.instance_extensions {
            print("    %, Ver.  %\n", to_string(it.extensionName.data), it.specVersion);        
          //  array_add(*vkal_info.instance_extensions, it);
        }
        print("\n");

        // Enable requested extensions
        // uint32_t required_extension_count = 0;
        // if (!SDL_Vulkan_GetInstanceExtensions(window, &required_extension_count, NULL)) {
        //     printf("[VKAL] %s\n", SDL_GetError());
        //     getchar();
        //     exit(-1);
        // }
        print("Load requested extensions:\n");
        print("--------------------------\n");
        required_extension_count : u32;
        if (!SDL_Vulkan_GetInstanceExtensions(window, *required_extension_count, null)) {
            print("    %\n", SDL_GetError());
            exit(-1); // TODO: Figure out how to really do this in jai.
        }
        print("    SDL wants % extensions:\n", required_extension_count);
        total_extension_count := required_extension_count + instance_extensions.count;
        // Get the required extensions that SDL tells us that we must have:
        all_instance_extensions := cast(**u8)alloc(256 * total_extension_count);
        //array_resize(*all_instance_extensions, required_extension_count);
        SDL_Vulkan_GetInstanceExtensions(window, *required_extension_count, all_instance_extensions);
        for i : 0..required_extension_count-1 {            
            print("        %\n", to_string(all_instance_extensions[i]));
        }        
        print("    You want those extensions:\n");
        for instance_extensions {
            print("        %\n", it);
        }
        j : u32 = 0;
        for i : required_extension_count..total_extension_count-1 {
            all_instance_extensions[i] =  cast(*u8)instance_extensions[j].data;
            j += 1;
        }        
        print("    All extensions:\n");
        for i : 0..total_extension_count-1 {
            print("        %\n", to_string(all_instance_extensions[i]));
        }

        print("Check requested Instance Extensions:\n");
        print("------------------------------------\n");
        for i : 0..total_extension_count-1 {
            print("    Check extension: % ", to_string(all_instance_extensions[i]));
            extension_ok := check_instance_extension_support(to_string(all_instance_extensions[i]));
            if !extension_ok {
                print("-> NOT AVAILABLE!\n");
            } else {
                print("-> OK!\n");
            }
        }
    }

    // Load validation layers (always for now)
    {
        // Check what is available
        print("Available Instance Layer:\n");
        print("-------------------------\n");
        vkEnumerateInstanceLayerProperties(*vkal_info.instance_layer_count, null);
        array_resize(*vkal_info.instance_layers, vkal_info.instance_layer_count);
        vkEnumerateInstanceLayerProperties(*vkal_info.instance_layer_count, vkal_info.instance_layers.data);
        for vkal_info.instance_layers {
            print("    %, Ver. %\n", to_string(it.layerName.data), it.specVersion);
        }
        print("\n");

        // enable requested layers
        print("Check requested Instance Layers:\n");
        print("--------------------------------\n");
        layer_ok := false;
        for instance_layers {
            print("    Check layer: % ", it);
            layer_ok = check_instance_layer_support(it);
            if !layer_ok {
                print("-> NOT AVAILABLE!\n");                
            } else {
                print("-> OK!\n");
            }
        }
        if layer_ok {
            create_info.enabledLayerCount = cast(u32)instance_layers.count;
            create_info.ppEnabledLayerNames = cast(**u8)*instance_layers.data;
        }
    }


}

check_instance_extension_support :: (extension_name : string) -> bool {
    for vkal_info.instance_extensions {
        if to_string(it.extensionName.data) == extension_name return true;
    }

    return false;
}

check_instance_layer_support :: (layer_name : string) -> bool {        
    for vkal_info.instance_layers {        
        if to_string(it.layerName.data) == layer_name return true;
    }
    
    return false;
}
