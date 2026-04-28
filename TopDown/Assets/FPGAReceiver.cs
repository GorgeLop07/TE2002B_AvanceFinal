using UnityEngine;
using System.IO.Ports;

public class FPGAReceiver : MonoBehaviour
{
    SerialPort serialPort;
    
    [Header("Configuración del Puerto Serial")]
    [Tooltip("Pon COM3, COM4, etc. si estás en Windows. O /dev/ttyUSB0 si estás en Linux nativo.")]
    public string portName = "COM3"; // <-- CAMBIA ESTO EN EL INSPECTOR DE UNITY
    public int baudRate = 115200; 

    // Variables globales
    public static float inputX = 0f;
    public static float inputY = 0f;
    public static bool gearUp = false;
    public static bool gearDown = false;

    private float tiempoSinMensajes = 0f;
    private static FPGAReceiver instance;

    void Awake()
    {
        instance = this;
    }

    void Start()
    {
        serialPort = new SerialPort(portName, baudRate);
        serialPort.ReadTimeout = 10;
        
        try 
        { 
            serialPort.Open(); 
            Debug.Log("<color=green>¡Puerto Serial abierto exitosamente en " + portName + "!</color>");
        } 
        catch (System.Exception e) 
        { 
            Debug.LogError("<color=red>Error al abrir el puerto serial: " + e.Message + "</color>");
        }
    }

    void Update()
    {
        tiempoSinMensajes += Time.deltaTime;

        // Si no llega nada en 150ms, anular movimiento (botones de marcha no se tocan)
        if (tiempoSinMensajes > 0.15f)
        {
            inputX = 0f;
            inputY = 0f;
        }

        if (serialPort == null || !serialPort.IsOpen || serialPort.BytesToRead <= 0)
            return;

        try
        {
            string data = serialPort.ReadExisting();

            foreach (char c in data)
            {
                tiempoSinMensajes = 0f;

                switch (c)
                {
                    case 'w':
                    case 'W':
                        inputY = 1f;
                        break;
                    case 's':
                    case 'S':
                        inputY = -1f;
                        break;
                    case 'a':
                    case 'A':
                        inputX = -1f;
                        break;
                    case 'd':
                    case 'D':
                        inputX = 1f;
                        break;
                    case '1':
                        gearUp = true;
                        break;
                    case '2':
                        gearDown = true;
                        break;
                }

                Debug.Log("FPGA char: " + c);
            }
        }
        catch (System.Exception e)
        {
            Debug.LogWarning("Error leyendo datos FPGA: " + e.Message);
        }
    }

    public static void EnviarByte(byte dato)
    {
        if (instance != null && instance.serialPort != null && instance.serialPort.IsOpen)
        {
            byte[] buffer = new byte[] { dato };
            try {
                instance.serialPort.Write(buffer, 0, 1);
            } catch { }
        }
    }

    void OnDestroy()
    {
        EnviarByte(0x00); 
        if (serialPort != null && serialPort.IsOpen) serialPort.Close();
    }
}