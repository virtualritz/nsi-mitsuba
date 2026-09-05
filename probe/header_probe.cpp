// T2.2 -- the first gate of specs/002-mitsuba-backend.
//
// Proves that Mitsuba's C++ headers are usable from a translation unit
// outside Mitsuba's own build tree, and that the result links against
// the built libraries. If this file does not compile and link, the C++
// shim is not viable and the fallback is `pyo3` over Mitsuba's nanobind
// API -- see specs/002-mitsuba-backend/research.md D3.
//
// The bar is deliberately low. `Properties` is the type every shim entry
// point has to touch, and `scene.h` transitively pulls in the CRTP-heavy
// render classes that make this uncertain in the first place.

// <cmath> before the Mitsuba headers: mitsuba/render/kdtree.h calls
// std::nextafter without including <cmath>. Mitsuba's own translation
// units pull it in transitively before reaching that header, so the bug
// is latent in its build and only surfaces in a consumer's. Finding this
// is what the gate is for; a shim header must do the same.
#include <cmath>

#include <mitsuba/core/properties.h>
#include <mitsuba/render/scene.h>

#include <cstdio>
#include <string>

int main() {
    // Instantiating Properties is what `contracts/shim.md` asks for: it
    // exercises the header, the ABI, and the link line in one step.
    mitsuba::Properties props("perspective");
    props.set("fov", 45.0);

    // Read it back, so the optimiser cannot discard the object and turn a
    // link failure into a silent pass. plugin_name() returns a
    // std::string_view, which is not null-terminated.
    if (props.plugin_name() != "perspective") {
        std::fprintf(stderr, "probe: unexpected plugin name\n");
        return 1;
    }

    const std::string name(props.plugin_name());
    std::printf("probe: Properties(\"%s\") constructed and read back\n",
                name.c_str());
    return 0;
}
