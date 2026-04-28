using UnityEngine;

public class laguna : MonoBehaviour
{
    [Header("Sonido")]
    [SerializeField] private AudioClip sonidoChoque;
    // OnTriggerEnter2D se ejecuta automáticamente cuando otro objeto con Collider entra en este Trigger
    private void OnTriggerEnter2D(Collider2D collision)
    {
        // 1. Verificamos si el objeto que entró es el jugador usando su Tag
        if (collision.CompareTag("Player"))
        {
            // 2. Buscamos el script PlayerMovement que está pegado al jugador
            PlayerMovement scriptJugador = collision.GetComponent<PlayerMovement>();

            if (sonidoChoque != null)
            {
                AudioSource.PlayClipAtPoint(sonidoChoque, Camera.main.transform.position);
            }

            Destroy(gameObject);
            // 3. Si lo encontramos, activamos la función de perder
            if (scriptJugador != null)
            {
                scriptJugador.TriggerLose();
            }
        }
    }
}