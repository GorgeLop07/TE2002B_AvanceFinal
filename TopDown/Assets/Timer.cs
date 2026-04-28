using UnityEngine;
using TMPro;

public class Timer : MonoBehaviour
{
    [Header("Configuración del Tiempo")]
    [SerializeField] private float tiempoMaximo = 60f;
    [SerializeField] private float puntosParaGanar = 75f;

    [Header("Referencias UI y Scripts")]
    [SerializeField] private TextMeshProUGUI textoTimer;
    [SerializeField] private Puntaje scriptPuntaje;
    [SerializeField] private PlayerMovement scriptJugador;

    private float tiempoActual;
    private bool juegoTerminado = false;

    void Start()
    {
        tiempoActual = tiempoMaximo;
        ActualizarTextoTimer();
    }

    void Update()
    {
        // Si el juego ya terminó, no hacemos nada más
        if (juegoTerminado) return;

        // 1. Reducir el tiempo de acuerdo a los cuadros por segundo
        tiempoActual -= Time.deltaTime;
        ActualizarTextoTimer();

        // 2. Comprobar Victoria: ¿Llegó a los 300 puntos antes de que acabe el tiempo?
        if (scriptPuntaje.ObtenerPuntos() >= puntosParaGanar)
        {
            TerminarJuego(verdaderoGanador: true);
        }
        // 3. Comprobar Derrota: ¿Se acabó el tiempo y no llegó a los puntos?
        else if (tiempoActual <= 0)
        {
            tiempoActual = 0; // Para que no muestre números negativos
            ActualizarTextoTimer();
            TerminarJuego(verdaderoGanador: false);
        }
    }

    private void TerminarJuego(bool verdaderoGanador)
    {
        juegoTerminado = true;

        if (verdaderoGanador)
        {
            scriptJugador.TriggerWin();
        }
        else
        {
            scriptJugador.TriggerLose();
        }
    }

    private void ActualizarTextoTimer()
    {
        // Mathf.Ceil redondea el número hacia arriba para que el jugador vea "30", "29", etc., sin decimales
        if (textoTimer != null)
        {
            textoTimer.text = "Tiempo: " + Mathf.Ceil(tiempoActual).ToString();
        }
    }
}