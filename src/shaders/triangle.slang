struct Vertex {
  float4 pos;
  float4 color;
};

struct Push {
  Vertex *vertices;
};

[[vk::push_constant]]
Push push;

struct VSOut {
  float4 pos : SV_Position;
  float3 color : COLOR;
};

[shader("vertex")]
VSOut vertexMain(uint id: SV_VertexID) {
  Vertex v = push.vertices[id];
  VSOut out;
  out.pos = v.pos;
  out.color = v.color.rgb;
  return out;
}

[shader("fragment")]
float4 fragmentMain(VSOut in) : SV_Target { return float4(in.color, 1.0); }

