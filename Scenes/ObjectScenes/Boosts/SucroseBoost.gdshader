shader_type canvas_item;

// --- COLORS ---
uniform vec3 backFillColour : source_color = vec3(0.62, 1.00, 1.00);
uniform vec3 frontFillInnerColour : source_color = vec3(0.35, 1.00, 1.00);
uniform vec3 frontFillOuterColour : source_color = vec3(0.00, 0.35, 1.00);
uniform vec3 ringColour : source_color = vec3(0.00, 0.16, 0.13);
uniform vec3 fresnelColour : source_color = vec3(0.00, 0.88, 1.00);
uniform vec3 innerRingGlowColour : source_color = vec3(0.00, 1.00, 1.00);
uniform vec3 outerRingGlowColour : source_color = vec3(1.0, 0.8, 0.1);
uniform vec3 specularColour : source_color = vec3(1.0, 1.0, 0.9);
uniform vec4 fillcolour : source_color = vec4(1.0);
uniform vec3 backgroundGradientInnerColour : source_color = vec3(0.13, 0.0, 0.4);
uniform vec3 backgroundGradientOuterColour : source_color = vec3(0.0, 0.0, 0.0);

// --- SHAPE & UV ---
uniform float uv_scale = -0.48;
uniform vec2 uv_offset = vec2(1.038, 1.038);
uniform float ringWidth : hint_range(0.0, 0.5) = 0.15;
uniform float innerCircleRadiusOffset : hint_range(-0.2, 0.2) = 0.0;
uniform float fill_value : hint_range(-1.0, 1.0) = 0.25;

// --- WAVES & ANIMATION ---
uniform float waveFrequency = 2.0;
uniform float waveAmplitude = 0.05;
uniform float waveAnimationSpeed = 2.0;
uniform float fillAnimationFrequency = 4.0;
uniform float fillAnimationAmplitude = 0.05;
uniform float fillProgressAnimationFreq = 1.0;
uniform float fillProgressAnimationAmp = 0.1;

// --- GLOW & LIGHTING ---
uniform float innerRingGlowWidth = 0.01;
uniform float innerRingGlowPowerBase = 1.2;
uniform float outerRingGlowWidth = 0.01;
uniform float outerRingGlowPowerBase = 0.8;
uniform float outerRingGlowAnimationSpeed = 12.0;
uniform float outerRingGlowAnimationRange = 0.2;
uniform float fresnelPower = 5.0;
uniform float frontFillFresnelPower = 5.0;

// --- SPECULAR (GLASS REFLECTION) ---
uniform float specularStrength = 0.2;
uniform float specularArcOffset = 0.35;
uniform float specularArcWidth = 0.07;
uniform float backgroundStrength = 0.65;


// Calculate distance to an arc
float sdArc(in vec2 p, in vec2 sc, in float ra, float rb) {
    p.x = abs(p.x);
    return ((sc.y*p.x > sc.x*p.y) ? length(p - sc*ra) : abs(length(p) - ra)) - rb;
}

// 2D Rotation Matrix
mat2 Get2DRotationMatrix(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat2(vec2(c, -s), vec2(s, c));
}

void fragment() {
    // Custom UV scaling based on your defaults
    vec2 uv = (UV / uv_scale) + uv_offset;
    vec2 normalizedCenteredUV = (uv - 0.5) * 2.0;
    
    float circleSDF = length(uv);
    float oneMinusRingWidth = 1.0 - ringWidth;
    
    // Ring Generation
    float circleA = step(circleSDF, 1.0);
    float circleB = step(circleSDF, oneMinusRingWidth);
    float ring = circleA - circleB;
    
    // Mask for the fluid container
    float fillMaskCircle = step(circleSDF, oneMinusRingWidth - innerCircleRadiusOffset);
    
    // Glow Calculations
    float ringGlowCircleSDF = circleSDF - 1.0;
    float innerRingGlowRadiusOffset = 0.15;
    
    float innerRingGlow = ringGlowCircleSDF + innerRingGlowRadiusOffset;   
    float outerRingGlow = ringGlowCircleSDF;   
    
    innerRingGlow = pow(innerRingGlowWidth / innerRingGlow, innerRingGlowPowerBase);
    innerRingGlow = clamp(innerRingGlow - fillMaskCircle, 0.0, 1.0); 
    
    float dynamicOuterGlowPower = outerRingGlowPowerBase + (sin(TIME * outerRingGlowAnimationSpeed) * outerRingGlowAnimationRange);
    outerRingGlow = pow(outerRingGlowWidth / outerRingGlow, dynamicOuterGlowPower);
    outerRingGlow = clamp(outerRingGlow - fillMaskCircle, 0.0, 1.0);
    
    // Wave Animation Math
    float fillAnimationPhase = TIME * fillAnimationFrequency;
    float fillAnimation = sin(fillAnimationPhase) * fillAnimationAmplitude;
    
    float frontWavePhase = (TIME * waveAnimationSpeed) + uv.x;
    float backWavePhase = (TIME * -waveAnimationSpeed) + uv.x;
    
    frontWavePhase *= waveFrequency;
    backWavePhase *= waveFrequency;
    
    float frontWaves = sin(frontWavePhase) * waveAmplitude;
    float backWaves = sin(backWavePhase + PI) * waveAmplitude;
            
    float verticalBand = sin(uv.x + (PI * 0.5)) - 0.3;
    verticalBand = smoothstep(0.1, 0.9, verticalBand);
    
    float animatedVerticalBand = (verticalBand * 0.125) * sin(TIME * fillAnimationFrequency);
            
    frontWaves += animatedVerticalBand;
    backWaves -= animatedVerticalBand;
    fillAnimation *= verticalBand;
            
    // Fill Progress
    float fillProgress = fill_value + (sin(TIME * fillProgressAnimationFreq * PI) * fillProgressAnimationAmp);
    
    float frontFill = step(uv.y, (fillAnimation + frontWaves) + fillProgress);
    float backFill = step(uv.y, (-fillAnimation + backWaves) + fillProgress);
    
    frontFill *= fillMaskCircle;
    backFill *= fillMaskCircle;
    backFill = clamp(backFill - frontFill, 0.0, 1.0);
    
    float fillMask = 1.0 - (frontFill + backFill);
    fillMask *= fillMaskCircle;
        
    float fill = frontFill + backFill;
    
    // Fresnel (Edge Shadow/Glow)
    float fresnel = clamp(pow((circleSDF + 0.01) * fillMask, fresnelPower), 0.0, 1.0);
    
    float frontFillFresnel = (circleSDF + 0.02) * (1.0 - fillMask);
    frontFillFresnel = clamp(pow(frontFillFresnel, frontFillFresnelPower), 0.0, 1.0);
    
    // Specular Highlight Arcs
    vec2 specularArcSC1 = vec2(sin(radians(15.0)), cos(radians(15.0)));
    vec2 specularArcSC2 = vec2(sin(radians(2.0)), cos(radians(2.0)));
    
    vec2 specularArcUV1 = Get2DRotationMatrix(radians(60.0)) * uv;
    vec2 specularArcUV2 = Get2DRotationMatrix(radians(28.0)) * uv;
    
    float specularArc1 = step(sdArc(specularArcUV1, specularArcSC1, 1.0 - specularArcOffset, specularArcWidth), 0.0);
    float specularArc2 = step(sdArc(specularArcUV2, specularArcSC2, 1.0 - specularArcOffset, specularArcWidth), 0.0);
    
    float specular = (specularArc1 + specularArc2) * specularStrength;
    
    // Compositing
    float mask = ring + fill + fresnel + specular;
    vec3 frontFillFinalColour = mix(frontFillInnerColour, frontFillOuterColour, frontFillFresnel);
    
    vec3 rgb = (ring * ringColour) + 
               (innerRingGlow * innerRingGlowColour) + 
               (outerRingGlow * outerRingGlowColour) + 
               ((frontFill * frontFillFinalColour) + (backFill * backFillColour)) * fillcolour.rgb + 
               (fresnel * fresnelColour) + 
               (specular * specularColour);
    
    // Background Gradient Presentation
    float backgroundGradient = smoothstep(0.0, 1.0, pow(length(normalizedCenteredUV), 0.6));
    vec3 background = mix(backgroundGradientInnerColour, backgroundGradientOuterColour, backgroundGradient);
    background = clamp(background - (fill + ring), 0.0, 1.0) * backgroundStrength;
    
    rgb += background;
    COLOR = vec4(rgb, mask) * COLOR;
}