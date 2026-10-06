# Weather atmosphere

Original SVG textures created for this port: soft clouds, mist, sunlight, light
motes and rain streaks. Gradients provide soft edges for broad weather passes.

`scripts/weather_atmosphere.gd` controls their opacity, motion and quiet intervals.
They are drawn beneath routes, delivery markers and the HUD.

Sunlight spans the map from top to bottom with a warm tint. Rain falls inside a
full-height curtain moving right to left; a translucent cartoon cloud crosses
left to right with a compact, rounded silhouette.
Fog gently covers the entire map and fades away. Quiet gaps keep these occasional.
