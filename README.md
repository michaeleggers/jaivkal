# VKAL in JAI

## Modifications in modules (that ship with the compiler) necessary:
Those notes are just for me (for now). Still experimenting...

- SDL: Add SDL_vulkan.jai and load the function pointers through #foreign SDL2, eg. for SDL_Vulkan_GetInstanceExtensions
- Vulkan: Add Vulkan 1.3 (check the compile time execution #run)

## Version history
### 4/18/2023
- Use https://github.com/osor-io/osor_vulkan/tree/master/generate_code to generat vulkan 'header' and 
  the loader code. Use that instead of the Vulkan module that shipped with the compiler since it
  had problems generating the bindings for Vulkan 1.3 C-header files.
  Copied the Osor-Vulkan module into the main ```modules``` dir of the compiler executable path because
  SDL_vulkan.h (added it myself) needs to see the definitions for eg. VkInstance structure types ->
  there is a ```#import "osor_vulkan"``` in the SDL_vulkan.jai. Not sure if this is good!!!
  