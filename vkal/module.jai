#import "Basic";
#import "SDL";
// #import "Vulkan";
#import "osor_vulkan";

VkalInfo :: struct {
    window : *SDL_Window;

    instance : VkInstance;
    surface  : VkSurfaceKHR;
    
    instance_extension_count : u32;
    instance_extensions      : [..]VkExtensionProperties;

    instance_layer_count : u32;
    instance_layers      : [..]VkLayerProperties;

    suitable_devices     : [..]VkalPhysicalDevice;

    selected_physical_device : VkalPhysicalDevice;

    queue_family_indices : VkalQueueFamilyIndices;
}

VkalSwapChainSupportDetails :: struct {
    capabilities  : VkSurfaceCapabilitiesKHR;
    formats       : [..]VkSurfaceFormatKHR;
    present_modes : [..]VkPresentModeKHR;
}

VkalQueueFamilyIndices :: struct {
    has_graphics_family : bool;
    graphics_family     : u32;
    has_present_family  : bool;
    present_family      : u32;
}

VkalPhysicalDevice :: struct {
    device     : VkPhysicalDevice;
    properties : VkPhysicalDeviceProperties;
}

VkalWantedFeatures :: struct {
    features11                      : VkPhysicalDeviceVulkan11Features;
    features12                      : VkPhysicalDeviceVulkan12Features;
    rayTracingPipelineFeatures      : VkPhysicalDeviceRayTracingPipelineFeaturesKHR;
    accelerationStructureFeatures   : VkPhysicalDeviceAccelerationStructureFeaturesKHR;
    features2                       : VkPhysicalDeviceFeatures2;
}

vkal_info : VkalInfo;

vkal_create_instance_sdl :: (window : *SDL_Window, instance_extensions : []string, instance_layers : []string) -> VkInstance {
    vkal_info.window = window;
    
    app_info := VkApplicationInfo.{
        sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
        pApplicationName = "vulkan application",
        applicationVersion = VK_MAKE_API_VERSION(0, 0, 1, 0),
        pEngineName = "cool vulkan rendering engine!",
        engineVersion = VK_MAKE_API_VERSION(0, 0, 1, 0),
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
            extension_ok := vkal_check_instance_extension_support(extension_name);
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
            layer_ok = vkal_check_instance_layer_support(it);
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

    // TODO: There should be a way to also print the calling function name?
    vkal_check_result(vkCreateInstance(*create_info, null, *vkal_info.instance));

    SDL_Vulkan_CreateSurface(vkal_info.window, vkal_info.instance, *vkal_info.surface); // TODO: Check for success.

    return vkal_info.instance;
}

vkal_check_result :: (result : VkResult) {
    assert(result == VK_SUCCESS, "VkResult was %\n", result);
}

vkal_check_instance_extension_support :: (extension_name : string) -> bool {
    for vkal_info.instance_extensions {
        if to_string(it.extensionName.data) == extension_name return true;
    }

    return false;
}

vkal_check_instance_layer_support :: (layer_name : string) -> bool {        
    for vkal_info.instance_layers {        
        if to_string(it.layerName.data) == layer_name return true;
    }
    
    return false;
}

vkal_find_suitable_devices :: (device_extension_names : []string) -> [..]VkalPhysicalDevice {
    print("Find Physical Devices:\n");
    print("----------------------\n");

    physical_device_count : u32;
    vkEnumeratePhysicalDevices(vkal_info.instance, *physical_device_count, null);
    if physical_device_count == 0 {
        print("    No Physical Devices found that support Vulkan!\n");
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
        if vkal_is_device_suitable(it, properties, device_extension_names) {
            indices := vkal_find_queue_families(it, vkal_info.surface);
            if indices.has_graphics_family && indices.has_present_family {
                array_add( *vkal_info.suitable_devices, VkalPhysicalDevice.{device = it, properties = properties} );
            }
        } else {
            print("DEVICE NOT SUITABLE!\n");
        }
    }
    
    return vkal_info.suitable_devices;
}

vkal_find_queue_families :: (physical_device : VkPhysicalDevice, surface : VkSurfaceKHR) -> VkalQueueFamilyIndices {
    queue_family_count : u32;
    vkGetPhysicalDeviceQueueFamilyProperties(physical_device, *queue_family_count, null);
    
    queue_family_properties : [..]VkQueueFamilyProperties;
    array_resize( *queue_family_properties, queue_family_count );

    vkGetPhysicalDeviceQueueFamilyProperties(physical_device, *queue_family_count, queue_family_properties.data);

    // Can we do graphics? If not this would suck...
    vkal_info.queue_family_indices = VkalQueueFamilyIndices.{has_graphics_family = false, has_present_family = false};
    for queue_family_properties {
        if it.queueFlags & VK_QUEUE_GRAPHICS_BIT {
            vkal_info.queue_family_indices.has_graphics_family = true;
            vkal_info.queue_family_indices.graphics_family = cast(u32)it_index; // TODO: it_index is s64. Find out why. Reread how_to!!!
            break;
        }
    }

    // Can we present pictures to the screen or is this a boring AI card with no video-out?
    for queue_family_properties {
        present_support : VkBool32;
        vkGetPhysicalDeviceSurfaceSupportKHR(physical_device, cast(u32)it_index, surface, *present_support); // TODO: Does 0/1 cast to true/false?
        if present_support {
            vkal_info.queue_family_indices.has_present_family = true;
            vkal_info.queue_family_indices.present_family = cast(u32)it_index;
            break;
        }
    }

    return vkal_info.queue_family_indices;
}

print_physical_device_properties :: (properties : VkPhysicalDeviceProperties) {
    print("    Device: %\n", to_string(properties.deviceName.data));
    print("        apiVersion: %\n", properties.apiVersion);
    print("        driverVersion: %\n", properties.driverVersion);
    print("        vendorID: %\n", properties.vendorID);
    print("        deviceID: %\n", properties.deviceID);
    print("        pipelineCacheUUID: %\n", properties.pipelineCacheUUID.data);
    print("\n");
}

vkal_is_device_suitable :: (physical_device : VkPhysicalDevice, properties : VkPhysicalDeviceProperties, device_extension_names : []string) -> bool {
    swapchain_support := vkal_query_swapchain_support(physical_device);

    swapchain_adequate := true;
    if swapchain_support.formats.count == 0 || swapchain_support.present_modes.count == 0 {
        swapchain_adequate = false;
    }

    return vkal_check_device_extension_support(physical_device, device_extension_names) && swapchain_adequate; // TODO: Implement    
}

vkal_check_device_extension_support :: (physical_device : VkPhysicalDevice, device_extension_names : []string) -> bool {
    print("    Check requested Device Extensions:\n");
    print("    ----------------------------------\n");
    supported_extension_count : u32;
    vkEnumerateDeviceExtensionProperties(physical_device, null, *supported_extension_count, null);
    available_extensions : [..]VkExtensionProperties;
    array_resize( *available_extensions, supported_extension_count );
    
    vkEnumerateDeviceExtensionProperties(physical_device, null, *supported_extension_count, available_extensions.data);
    unavailable_extensions : [..]bool;
    array_resize( *unavailable_extensions, device_extension_names.count );
    found_extensions_count : u32;
    for requested_extension_name, requested_extension_index : device_extension_names {
        current_name := requested_extension_name;
        print("        Check Device Extension % ", current_name);
        for available_extensions {
            if current_name == to_string(it.extensionName.data) {
                print("-> OK!\n");
                unavailable_extensions[requested_extension_index] = true;
                found_extensions_count += 1;
                break;
            }
        }
    }

    for unavailable_extensions {
        if !it {
            print("-> NOT FOUND!\n");
        }
    }

    return found_extensions_count == device_extension_names.count;
}

vkal_query_swapchain_support :: (physical_device : VkPhysicalDevice) -> VkalSwapChainSupportDetails {
    details : VkalSwapChainSupportDetails;

    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, vkal_info.surface, *details.capabilities);

    format_count : u32;
    vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, vkal_info.surface, *format_count, null);
    array_resize(*details.formats, format_count);
    vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, vkal_info.surface, *format_count, details.formats.data);

    present_mode_count : u32;
    vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, vkal_info.surface, *present_mode_count, null);
    array_resize(*details.present_modes, present_mode_count);
    vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, vkal_info.surface, *present_mode_count, details.present_modes.data);

    return details;    
}

vkal_select_physical_device :: (physical_device : VkalPhysicalDevice) {
    vkal_info.selected_physical_device = physical_device;
}

/* 
    There actually is not really such a thing as a logical device but we use the VkDevice handle
    created by this function as a way to communicate with the actual GPU.
*/
vkal_create_logical_device :: (device_extension_names : []string, wanted_features : VkalWantedFeatures) -> VkDevice {
    unique_queue_families : [2]u32;
    unique_queue_families[0] = vkal_info.queue_family_indices.graphics_family;
    unique_queue_families[1] = vkal_info.queue_family_indices.present_family;
    
    queue_create_infos : [2]VkDeviceQueueCreateInfo;
    info_count : u32;
    if vkal_info.queue_family_indices.graphics_family != vkal_info.queue_family_indices.present_family {
        info_count = 2;
    } else {
        info_count = 1;
    }

    queue_prio : float32;
    for i : 0..info_count {
        queue_create_infos[i] = VkDeviceQueueCreateInfo.{
            sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            queueFamilyIndex = unique_queue_families[i],
            queueCount = 1,
            pQueuePriorities = *queue_prio
        };
    }

    // features.features11.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES;
    // features.features12.sType = VK_STRUCTURE_TYPE_PHYISCAL_DEVICE_VULKAN_1_2_FEATURES;
    // features.rayTracingPipelineFeatures.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_FEATURES_KHR;
    // features.accelerationStructureFeatures.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR;
    // features.features11.pNext = *features.features12;
    // features.features12.pNext = *features.rayTracingPipelineFeatures;
    // features.rayTracingPipelineFeatures.pNext = *vulkan_features.accelerationStructureFeatures;
    

    /*
    // Remove later
    MyType :: struct {
        a : u32;
        b : float64;
    }

    print_fields_of_type :: ($T: Type) {
        #run {
            print("% \n", T);            
            print("Type Info: %\n", type_info(T));
            ti_T := type_info(T);
            print("%\n", << ti_T);
            for member : ti_T.members {
                type_of_member := member.type;
                print("   Name: %\n", member.name);
                print("   Type: %\n", << type_of_member);
                print("   Type Address: %\n", type_of_member);
                for member : type_of_member.members {

                }
                

                // How can I get the name of the type?
            }
        }
    }
    
    // print_fields_of_type(MyType);


    print_fields_of_value :: (value: $T) {
        #run {
            print("% \n", T);            
            print("Type Info: %\n", type_info(T));
            ti_T := type_info(T);
            print("%\n", << ti_T);
        }
    }

    
    myThing : MyType;
    // print_fields_of_value(myThing);
    // !Remove later

    #run print("fields VkalWantedFeatues\n");
    print_fields_of_type(VkalWantedFeatures);

    */

    // TODO: Find out how to do this for Enums so we can actually create the feature-chain and set the wanted_features
    //       at compile time.

    
    // Query what features are available for this device
    features11 := VkPhysicalDeviceVulkan11Features.{ sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES };
    features12 := VkPhysicalDeviceVulkan12Features.{ sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES, pNext = *features11 };
    raytracing_features := VkPhysicalDeviceRayTracingPipelineFeaturesKHR.{ sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_FEATURES_KHR, pNext = *features12 };
    accelerationstruct_features := VkPhysicalDeviceAccelerationStructureFeaturesKHR.{ sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR, pNext = *raytracing_features };
    features2 := VkPhysicalDeviceFeatures2.{ sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2, pNext = *accelerationstruct_features };
    vkGetPhysicalDeviceFeatures2(vkal_info.selected_physical_device.device, *features2);

    /* Check features2 (which now contains VkPhysicalDeviceFeatures) */
    // vk_structure_type_names := #run enum_names(VkStructureType);
    // for * vk_structure_type_names {
    //     print("%\n", << it);
    // }


    features11_ptr := *features11;
    wanted_features11_ptr := *wanted_features.features11;
    features11_ti := type_info(type_of(features11));


    print("Value: %\n", (<< wanted_features11_ptr));
    
    thing := << wanted_features11_ptr;
    print("Thing: %\n", thing);
    sType :: type_of(thing.sType);
    print("type of sType of thing: %\n", sType);
    
    FeatureHeader :: struct {
        sType : VkStructureType;
        pNext := null;
    }

    current_field_ptr := cast(*u8)wanted_features11_ptr + size_of(FeatureHeader);
    end_of_features11_ptr := cast(*u8)wanted_features11_ptr + size_of(type_of(wanted_features.features11));
    while current_field_ptr != end_of_features11_ptr {
        bool_ptr := cast(*VkBool32)current_field_ptr;
        type_of_field := type_of(<< current_field_ptr);
        print("Field: ");
        print("type: %, ", type_of_field);
        print("value: %", << current_field_ptr);
        break;

    }


    // Check out 030_any and 170_modify for more info about type-stuff...

    wanted_features11_ptr_as_u8 := cast(*u8)(*wanted_features.features11);
    features11_ptr_as_u8 := cast(*u8)*features11;
    print("\n\n");
    for member : features11_ti.members {            
        print("Name: %, Type: %, Runtime-Size: %\n", member.name, member.type.type, member.type.runtime_size);
        print("    %\n", member);

        field_type_info := cast(*Type_Info)member.type;
        print("    Thing: %\n", field_type_info.type);


        wanted_feature_value := << cast(*VkBool32)wanted_features11_ptr_as_u8;
        features_value := << cast(*VkBool32)features11_ptr_as_u8;
        print("    Wanted Features11-Value: %\n", wanted_feature_value);
        print("    Features11-Value: %\n", features_value);
        if wanted_feature_value && !features_value {
            print("########## FEATURE % not supported! #########\n", member.name);
        }

        wanted_features11_ptr_as_u8 = wanted_features11_ptr_as_u8 + member.type.runtime_size;
        features11_ptr_as_u8 = features11_ptr_as_u8 + member.type.runtime_size;

        print("\n\n");
        

        // print("Name: %, Value: %\n", member.name,  << features11_ptr);
        // print("\n");
        // print("Value: %\n", (<< wanted_features11_ptr));
        // thing := << wanted_features11_ptr;
        
    }

}
