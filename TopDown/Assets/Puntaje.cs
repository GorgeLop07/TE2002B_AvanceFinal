using UnityEngine;
using TMPro;

public class Puntaje : MonoBehaviour
{
    private float puntos;
    private TextMeshProUGUI textMesh;

    private void Start()
    {
        textMesh = GetComponent<TextMeshProUGUI>();
        textMesh.text = puntos.ToString();
    }

    public void SumarPuntos(float puntosEntrada)
    {
        puntos += puntosEntrada;
        textMesh.text = puntos.ToString();

        // --- LÓGICA PARA LA FPGA (Datos en vivo en formato BCD) ---
        // Nos aseguramos de manejarlo como entero para la matemática de bits
        int puntosInt = Mathf.FloorToInt(puntos);

        // Tope de seguridad por si agarras puntos extra (para no desbordar 2 displays)
        if (puntosInt > 99) puntosInt = 99;

        // Extraemos decenas y unidades
        int decenas = puntosInt / 10;
        int unidades = puntosInt % 10;

        // Desplazamos las decenas 4 bits a la izquierda y sumamos (con OR) las unidades
        // Ejemplo con 75: decenas (7 = 0111) se vuelve 01110000. unidades (5 = 0101).
        // Resultado final: 0111 0101 (0x75 en hex, que la FPGA lee directo como 7 y 5).
        byte datoAEnviar = (byte)((decenas << 4) | unidades);

        // Le mandamos la orden al script del Serial para que envíe la info a la DE10-Lite
        FPGAReceiver.EnviarByte(datoAEnviar);
    }

    public float ObtenerPuntos()
    {
        return puntos;
    }
}