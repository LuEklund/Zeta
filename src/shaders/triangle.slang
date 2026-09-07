struct VSOut {
  float4 pos : SV_Position;
  float3 color : COLOR;
};

static const float2 positions[3] = {
  float2(0.0, -0.5),
  float2(0.5, 0.5),
  float2(-0.5, 0.5),
};

static const float3 colors[3] = {
  float3(1.0, 0.0, 0.0),
  float3(0.0, 1.0, 0.0),
  float3(0.0, 0.0, 1.0),
};

[shader("vertex")]
VSOut vertexMain(uint id: SV_VertexID) {
  VSOut out;
  out.pos = float4(positions[id], 0.0, 1.0);
  out.color = colors[id];
  return out;
}

[shader("fragment")]
float4 fragmentMain(VSOut in) : SV_Target { return float4(in.color, 1.0); }
