#import "Basic";
#import "SDL";
#import "Vulkan";

//#import,dir "../osor_vulkan";

VkalInfo :: struct {
    window : *SDL_Window;

    instance : VkInstance;

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
        applicationVersion = VK_MAKE_VERSION(0, 0, 1),
        pEngineName = "cool vulkan rendering engine!",
        engineVersion = VK_MAKE_VERSION(0, 0, 1),
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
        print("Available Instance Extensions:\n");
        print("------------------------------\n");                
        array_resize(*vkal_info.instance_extensions, vkal_info.instance_extension_count);
        vkEnumerateInstanceExtensionProperties(null, *vkal_info.instance_extension_count, vkal_info.instance_extensions.data);
        for vkal_info.instance_extensions {
            print("    %, Ver.  %\n", to_string(it.extensionName.data), it.specVersion);                  
        }
        print("\n");

        // Get necessary extensions requested by SDL and add our own to the list
        print("Load requested extensions:\n");
        print("--------------------------\n");
        required_extension_count : u32;
        if (!SDL_Vulkan_GetInstanceExtensions(window, *required_extension_count, null)) {
            print("    %\n", SDL_GetError());
            exit(-1); // TODO: Figure out how to really do this in jai.
        }
        print("    SDL wants % extensions:\n", required_extension_count);
        total_extension_count : u32 = required_extension_count + cast(u32)instance_extensions.count;
        all_instance_extensions := cast(**u8)alloc(256 * total_extension_count); // TODO: destroy
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
        print("\n");

        // Finally, check if extensions requested by SDL and us are available.
        // Enable them, if that is the case.
        print("Check requested Instance Extensions:\n");
        print("------------------------------------\n");
        supported_extensions : [..]string;
        for i : 0..total_extension_count-1 {
            extension_name := to_string(all_instance_extensions[i]);
            print("    Check extension: % ", extension_name);
            extension_ok := check_instance_extension_support(extension_name);
            if !extension_ok {
                // TODO: Should we abort here?                
                print("-> NOT AVAILABLE!\n");
            } else {
                array_add(*supported_extensions, extension_name);
                print("-> OK!\n");
            }
        }
        create_info.enabledExtensionCount = total_extension_count;
        create_info.ppEnabledExtensionNames = all_instance_extensions;
        
        print("\n");
    }

    // Load validation layers (always for now)
    {
        // Check what is available
        print("Available Instance Layers:\n");
        print("--------------------------\n");
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
        instance_layers_ptr := cast(**u8)alloc(256 * instance_layers.count); // TODO: Destroy
        layer_ok := false;
        for instance_layers {
            print("    Check layer: % ", it);
            layer_ok = check_instance_layer_support(it);
            if !layer_ok {
                // TODO: Should we abort here?
                print("-> NOT AVAILABLE!\n");                
            } else {
                instance_layers_ptr[it_index] = cast(*u8)it.data;
                print("-> OK!\n");
            }
        }
        if layer_ok {
            create_info.enabledLayerCount = cast(u32)instance_layers.count;
            create_info.ppEnabledLayerNames = instance_layers_ptr;
        }
        print("\n");
    }

    // TODO: There should be a way to make checking the VkResult polymorphic.
    result := vkCreateInstance(*create_info, null, *vkal_info.instance);
    if result != .SUCCESS { // TODO: Will not complain about non existent layer names!!!
        print("Sorry! vkCreateInstance failed: %\n", result);
        exit(-1);
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

vkal_find_suitable_devices :: (device_extension_names : []string) -> [..]VkPhysicalDevice {
    print("Find Physical Devices:\n");
    print("----------------------\n");
    physical_device_count : u32;
    vkEnumeratePhysicalDevices(vkal_info.instance, *physical_device_count, null);
    if physical_device_count == 0 {
        print("     No Physical Devices found that support Vulkan!\n");
        exit(-1);
    } else {
        print("    Physical Device Count: %\n", physical_device_count);
    }
    print("\n");

    print("Find Suitable Devices:\n");
    print("----------------------\n");
    suitable_device_count : u32;
    physical_devices : [..]VkPhysicalDevice;
    array_resize(*physical_devices, physical_device_count);
    vkEnumeratePhysicalDevices(vkal_info.instance, *physical_device_count, physical_devices.data);
    for physical_devices {
        properties : VkPhysicalDeviceProperties;
        vkGetPhysicalDeviceProperties(it, *properties);
        print_physical_device_properties(properties);
    }
}

print_physical_device_properties :: (properties : VkPhysicalDeviceProperties) {
    print("Device: %\n", to_string(properties.deviceName.data));
    print("    apiVersion: %\n", properties.apiVersion);
    print("    driverVersion: %\n", properties.driverVersion);
    print("    vendorID: %\n", properties.vendorID);
    print("    deviceID: %\n", properties.deviceID);
    print("    pipelineCacheUUID: %\n", properties.pipelineCacheUUID.data);
}