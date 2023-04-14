# VKAL in JAI

## Modifications in modules (that ship with the compiler) necessary:
Those notes are just for me (for now). Still experimenting...

- SDL: Add SDL_vulkan.jai and load the function pointers through #foreign SDL2, eg. for SDL_Vulkan_GetInstanceExtensions
- Vulkan: Add Vulkan 1.3 (check the compile time execution #run)

