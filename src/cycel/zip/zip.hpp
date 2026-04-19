#include <vector>
#include <string>
#include <cstdint>

struct ZipFile {
    std::string filename;
    std::vector<uint8_t> data;
};

std::vector<ZipFile> extract_zip(const uint8_t* data, size_t size);