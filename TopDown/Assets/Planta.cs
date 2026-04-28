using UnityEngine;

public class Planta : MonoBehaviour
{
    [SerializeField] private float cantidadPuntos;
    [SerializeField] private Puntaje puntaje;
    
    [Header("Sonido")]
    [SerializeField] private AudioClip sonidoRecoleccion;

    private void OnTriggerEnter2D(Collider2D collision)
    {
        if (collision.CompareTag("Player"))
        {
            puntaje.SumarPuntos(cantidadPuntos);
            
            // Reproduce el sonido en la posición de la cámara
            if (sonidoRecoleccion != null) 
            {
                AudioSource.PlayClipAtPoint(sonidoRecoleccion, Camera.main.transform.position);
            }

            Destroy(gameObject);
        }
    }
}