precision mediump float;

attribute vec4 vertex_position;
attribute vec4 vertex_color;
uniform   mat4 projection_matrix;
varying   vec4 fragColor;

void main()
{
    fragColor   = vertex_color;
    gl_Position = projection_matrix * vertex_position;
}
