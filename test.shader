Shader "Unlit/test"
{
    Properties
    {
        
    }
    
    SubShader
    {
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            
            float4 vert(float4 vertex : POSITION) : SV_POSITION
            {
                return mul(UNITY_MATRIX_MVP, vertex);
            }
            fixed4 frag () : SV_Target
            {
                return _Color;
            }
            ENDHLSL
        }
    }
}
