from pathlib import Path

mapping = {
    'assets/lottie/0162a26e-d52a-11ee-bcd6-67c03a302c6b.json': 'assets/lottie/car_animation.json',
    'assets/lottie/035712be-1188-11ee-b802-03488d7a9ca6.json': 'assets/lottie/woman_with_suitcase.json',
    'assets/lottie/0788f03a-1176-11ee-9d26-5384a7bf7c91.json': 'assets/lottie/walk_animation.json',
    'assets/lottie/0d7b2322-8f58-11ee-b5d5-6fc5f7fe081f.json': 'assets/lottie/man_walking.json',
    'assets/lottie/3335e6ad-0743-4808-82b6-f167dfd7c122.json': 'assets/lottie/main_scene_buttons.json',
    'assets/lottie/369d8ba8-1183-11ee-a1da-ebc5cdd76cdc.json': 'assets/lottie/smoking_man.json',
    'assets/lottie/43464d9c-ff01-11ee-bfdb-0bff70c8ac47.json': 'assets/lottie/camper_van.json',
    'assets/lottie/4cd14660-1185-11ee-ad9e-039e899dd06b.json': 'assets/lottie/cheeky_car.json',
    'assets/lottie/4de798bc-ce4c-11ef-8e61-035cca1908c6.json': 'assets/lottie/abstract_layers.json',
    'assets/lottie/50df7ff8-32e7-11f0-9483-237297af89eb.json': 'assets/lottie/rabbit_head.json',
    'assets/lottie/567a7fc4-847b-11ee-aba4-037b9d590693.json': 'assets/lottie/walking_man_smile.json',
    'assets/lottie/5e08b0dd-f863-4b30-9898-2706d509ff9b.json': 'assets/lottie/timing_animation.json',
    'assets/lottie/66b07390-1189-11ee-96db-6f41ff4a5a31.json': 'assets/lottie/bird_walk_cycle.json',
    'assets/lottie/6d0cba5c-5e85-11ee-8add-ef0ffb3f0f9f.json': 'assets/lottie/shapes_comp2.json',
    'assets/lottie/77063c7e-9064-11ef-94b0-a7013287ee00.json': 'assets/lottie/love_hand.json',
    'assets/lottie/7b580292-c717-11ee-bd43-2b948789ee78.json': 'assets/lottie/simple_shape_animation.json',
    'assets/lottie/8942ad9c-1189-11ee-8b52-3f0a09f0ff93.json': 'assets/lottie/letter_c_animation.json',
    'assets/lottie/Sample Animation.json': 'assets/lottie/skateboard_speed_lines.json',
    'assets/lottie/a5a21ef2-4787-11ef-9abf-4b32624af444.json': 'assets/lottie/crystal_square.json',
    'assets/lottie/bab31096-1171-11ee-8344-a39c7b7d9874.json': 'assets/lottie/countdown_logo.json',
    'assets/lottie/bef9233e-117b-11ee-a45b-cbf027960c00.json': 'assets/lottie/relax_on_the_beach.json',
    'assets/lottie/car_search.json': 'assets/lottie/car_search.json',
    'assets/lottie/cc77c6a2-cc95-11ee-b2a6-d3b7f8367623.json': 'assets/lottie/toggle_day_night.json',
    'assets/lottie/d333e5b2-3796-11f0-b859-93751d2de7ce.json': 'assets/lottie/wind_pose.json',
    'assets/lottie/eddf77f9-597b-49c0-ba61-927df26f9bf2.json': 'assets/lottie/main_scene_shapes.json',
    'assets/lottie/fc7b10f2-1188-11ee-af61-6f972fda9875.json': 'assets/lottie/road_trip.json',
    'assets/lottie/Car.json': 'assets/lottie/car_animation_copy.json',
    'assets/lottie/Road_Trip.json': 'assets/lottie/countdown_logo_copy.json',
}

# Rename the existing road_trip.json first if it exists and conflicts
old_road = Path('assets/lottie/road_trip.json')
if old_road.exists() and old_road.name == 'road_trip.json' and old_road not in [Path(k) for k in mapping]:
    old_road.rename(Path('assets/lottie/countdown_logo_copy.json'))

for src, dst in mapping.items():
    srcp = Path(src)
    dstp = Path(dst)
    if not srcp.exists():
        print('MISSING', src)
        continue
    if dstp.exists():
        print('EXISTS', dst)
        continue
    srcp.rename(dstp)
    print('RENAMED', src, '->', dst)
