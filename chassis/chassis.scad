// weftplate chassis: an ear-mount frame that ties decorator (Decora) devices
// into one piece that still installs like ordinary devices.
//
// The frame sits BEHIND the device ears, between the ears and the box. Each ear
// drops into a pocket as deep as the strap is thick, so the front of the frame
// is flush with the front of the ears and the wallplate sees no extra height.
// Split snap pins through the ear holes hold the devices in until installation
// and release when their caps are squeezed together.
// The frame never takes a screw of its own. Each device's box screws pass through
// oversized slots in the floor and clamp ear -> frame -> box, so the devices hold
// the whole assembly in the box.
//
// Coordinates (mm): X runs across the gangs, Y along the strap (the device's long
// axis), Z from the box side (z = 0) toward the wallplate. Origin is the center
// of the gang group.
//
// Render: openscad -o chassis.stl chassis.scad
//         openscad -o chassis.stl -D gangs=3 -D ear_w=38 chassis.scad

/* [Layout] */
gangs = 2;                  // number of devices side by side
gang_pitch = 46.04;         // center-to-center between gangs (1-13/16", standard)

/* [Standard interface: fixed by NEMA, don't change] */
box_screw_cc = 83.34;       // box mounting screws (6-32), 3-9/32" c-c
plate_screw_cc = 96.84;     // decorator wallplate screws (6-32, tapped in the strap), 3-13/16" c-c

/* [Device strap: measure your devices] */
strap_len = 106;            // overall length of the strap, end to end
ear_w = 40;                 // widest part of the ear, including any plaster-ear tabs
ear_t = 1.2;                // strap thickness (Hubbell specs: 1.2-1.3)
body_w = 44.5;              // widest part of the device behind the strap, terminal screws included
body_len = 74;              // length of the device behind the strap (sets the window length)

/* [Chassis] */
floor_t = 1.2;              // material behind the ears; the devices stand off the wall by this much
end_wall = 1.5;             // material beyond the strap ends
side_wall = 3;              // material outside the outermost window/pocket edges
corner_r = 2;               // outline corner radius
fit = 0.3;                  // clearance per side around the ears
pocket_extra_d = 0.1;       // extra pocket depth beyond ear_t

/* [Clearances in the floor] */
screw_slot_w = 8;           // box-screw clearance across the strap (6-32 is 3.5; room for self-grounding clips)
screw_slot_l = 7;           // box-screw clearance along the strap (the device slot lets the screw float)
plate_screw_d = 4;          // clearance for the wallplate screw tips behind the ear
min_web = 1;                // least material between the box-screw slot and the wallplate-screw hole

/* [Ear holes: the hole in each plaster ear, two per strap end; measure your devices] */
// Each end of the strap flares into two plaster ears, one either side of the box
// screw, each with a hole. The two ear holes sit wider and nearer the strap end
// than the box screw, so with it they form a triangle pointing at the far end.
ear_hole_d = 3.5;           // ear hole diameter
ear_hole_dx = 12;           // ear hole offset across the strap, from the strap centerline
ear_hole_dy = 6;            // ear hole offset toward the strap end, from the box screw

/* [Retainer pins: a split snap pin through each ear hole] */
// The pin is split in two by a slot. Pressing the ear down squeezes the capped
// halves through the ear hole, and they spring back so the cap's flat underside
// catches the front of the ear. Squeeze the cap halves together to release.
pin_fit = 0.2;              // clearance per side between pin shank and ear hole
pin_slot_w = 1.2;           // width of the split; must exceed the total squeeze (2 * pin_cap_overhang)
pin_cap_overhang = 0.25;    // how far the cap reaches past the ear hole edge, per side
pin_cap_land = 0.4;         // straight section of the cap above its underside
pin_cap_h = 1.6;            // cap height above the front of the ear (stands proud under the wallplate)
pin_tip_d = 2.2;            // cap diameter at the tip (sets the lead-in taper)

/* [Snap nubs: set nub_overhang = 0 to disable] */
nub_overhang = 0.4;         // how far a nub reaches over the ear edge
nub_t = 0.6;                // nub height above the frame face (the only part that stands proud of the ears)
nub_len = 6;                // nub length along the strap
nub_base = 1.5;             // nub footprint behind the pocket edge

$fn = 48;
eps = 0.01;

pocket_w = ear_w + 2 * fit;
pocket_d = ear_t + pocket_extra_d;
frame_t = floor_t + pocket_d;
span = (gangs - 1) * gang_pitch;                       // first to last gang center
frame_w = span + max(body_w, pocket_w) + 2 * side_wall;
frame_l = strap_len + 2 * fit + 2 * end_wall;
ear_y0 = body_len / 2;                                 // where the pocket meets the window
ear_y1 = strap_len / 2 + fit;                          // strap end

ear_hole_y = box_screw_cc / 2 + ear_hole_dy;
pin_shank_d = ear_hole_d - 2 * pin_fit;
pin_cap_d = ear_hole_d + 2 * pin_cap_overhang;
pin_cap_z = floor_t + pocket_d;                        // cap underside, just above the front of the ear

// Rough bending strain at each prong root while it squeezes through the hole
// (cantilever: 1.5 * thickness * deflection / length^2). Keep it under the
// material's allowable snap-fit strain: roughly 2-3% for PETG, 4% for PC.
pin_prong_t = (pin_shank_d - pin_slot_w) / 2;
pin_strain = 1.5 * pin_prong_t * pin_cap_overhang / pow(pin_cap_z + pin_cap_land, 2);
echo(str("retainer pin root strain ~", round(pin_strain * 1000) / 10, "%"));

function gang_x(i) = i * gang_pitch - span / 2;

assert(pocket_w < gang_pitch, "ear_w is too wide for the gang pitch");
assert(box_screw_cc / 2 - screw_slot_l / 2 - ear_y0 >= min_web,
       "box-screw slot breaks into the body window; shorten body_len or screw_slot_l");
assert(ear_hole_dx + ear_hole_d / 2 < pocket_w / 2, "ear holes fall outside the ear; check ear_hole_dx and ear_w");
assert(ear_hole_y + ear_hole_d / 2 < ear_y1, "ear holes fall past the strap end; check ear_hole_dy and strap_len");
assert(pin_slot_w > 2 * pin_cap_overhang,"pin_slot_w is too narrow for the cap to squeeze through the ear hole");
assert(pin_tip_d < ear_hole_d, "pin_tip_d must be smaller than the ear hole to start the lead-in");
assert(plate_screw_cc / 2 < ear_y1, "strap_len is too short to reach the wallplate screws");
assert((plate_screw_cc - box_screw_cc) / 2 - screw_slot_l / 2 - plate_screw_d / 2 >= min_web,
       "box-screw slot and wallplate-screw hole merge; shorten screw_slot_l or plate_screw_d");

module rounded_rect(w, l, r) {
    offset(r) square([w - 2 * r, l - 2 * r], center = true);
}

module nub() {
    // Cross-section in X-Z, extruded along Y. The pocket edge is at x = 0 and the
    // pocket lies toward +x. The sloped top guides the ear in as it is pushed down.
    rotate([90, 0, 0])
        linear_extrude(nub_len, center = true)
            polygon([[-nub_base, 0], [nub_overhang, 0], [nub_overhang, 0.15],
                     [0, nub_t], [-nub_base, nub_t]]);
}

// The slot runs along Y, so the two prongs sit side by side across the strap.
module pin_slot() {
    translate([-pin_slot_w / 2, -pin_cap_d / 2 - eps, -eps])
        cube([pin_slot_w, pin_cap_d + 2 * eps, pin_cap_z + pin_cap_h + 2 * eps]);
}

// Split snap pin, origin at the ear hole center on the back of the frame.
module retainer_pin() {
    difference() {
        union() {
            translate([0, 0, floor_t - eps])
                cylinder(d = pin_shank_d, h = pocket_d + 2 * eps);
            translate([0, 0, pin_cap_z]) {
                cylinder(d = pin_cap_d, h = pin_cap_land + eps);
                translate([0, 0, pin_cap_land])
                    cylinder(d1 = pin_cap_d, d2 = pin_tip_d, h = pin_cap_h - pin_cap_land);
            }
        }
        pin_slot();
    }
}

module chassis() {
    difference() {
        linear_extrude(frame_t) rounded_rect(frame_w, frame_l, corner_r);

        // one window for all device bodies
        translate([0, 0, -eps])
            linear_extrude(frame_t + 2 * eps) square([span + body_w, body_len], center = true);

        for (i = [0 : gangs - 1], s = [-1, 1]) {
            x = gang_x(i);
            // ear pocket
            translate([x - pocket_w / 2, s > 0 ? ear_y0 - eps : -ear_y1, floor_t])
                cube([pocket_w, ear_y1 - ear_y0 + eps, pocket_d + eps]);
            // box screw clearance
            translate([x, s * box_screw_cc / 2, -eps])
                linear_extrude(frame_t + 2 * eps)
                    rounded_rect(screw_slot_w, screw_slot_l, min(screw_slot_w, screw_slot_l) / 2 - eps);
            // wallplate screw tip clearance
            translate([x, s * plate_screw_cc / 2, -eps])
                cylinder(d = plate_screw_d, h = frame_t + 2 * eps);
        }

        // split the pins down through the floor so the prongs flex over their full height
        for (i = [0 : gangs - 1], s = [-1, 1], side = [-1, 1])
            translate([gang_x(i) + side * ear_hole_dx, s * ear_hole_y, 0])
                pin_slot();
    }

    for (i = [0 : gangs - 1], s = [-1, 1], side = [-1, 1])
        translate([gang_x(i) + side * ear_hole_dx, s * ear_hole_y, 0])
            retainer_pin();

    // nubs on both side walls of every pocket, centered between the box screw
    // and the wallplate screw
    if (nub_overhang > 0)
        for (i = [0 : gangs - 1], s = [-1, 1], side = [-1, 1])
            translate([gang_x(i) + side * pocket_w / 2,
                       s * (box_screw_cc + plate_screw_cc) / 4,
                       frame_t])
                mirror([side > 0 ? 1 : 0, 0, 0]) nub();
}

chassis();
