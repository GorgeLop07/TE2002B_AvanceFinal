using System.Collections;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.SceneManagement;
using TMPro;

public enum TractorGear
{
    Neutral,
    First,
    Second,
    Third,
    Reverse
}

public class PlayerMovement : MonoBehaviour
{
    [Header("Transici�n de Niveles")]
    [Tooltip("El n�mero de la escena a la que vas al ganar. (Pon 0 en tu �ltimo nivel)")]
    [SerializeField] private int nextSceneIndex = 2;
    [Tooltip("El n�mero de la pantalla de carga o men� a la que vas al perder.")]
    [SerializeField] private int menuOrLoadingIndex = 0;
    [Tooltip("Tiempo de espera tras ganar/perder antes de cambiar de escena.")]
    [SerializeField] private float waitTimeAfterEnd = 5f;

    [Header("Configuraci�n Especial del Nivel")]
    [Tooltip("Activa esto en el Nivel 3 para que solo se pueda usar la reversa.")]
    [SerializeField] private bool isReverseOnlyLevel = false;

    [Header("Configuraci�n de Marchas (Velocidades)")]
    [SerializeField] private float speedFirstGear = 3f;
    [SerializeField] private float speedSecondGear = 6f;
    [SerializeField] private float speedThirdGear = 10f;
    [SerializeField] private float speedReverse = 2.5f;

    [Header("Paneles de UI")]
    [SerializeField] private GameObject winPanel;
    [SerializeField] private GameObject losePanel;
    [SerializeField] private TextMeshProUGUI gearText;

    [Header("Efectos de Sonido")]
    [SerializeField] private AudioClip winSound;
    [SerializeField] private AudioClip loseSound;

    private Rigidbody2D rb;
    private Vector2 moveInput;
    private Animator animator;

    private TractorGear currentGear = TractorGear.Neutral;
    private float currentMoveSpeed = 0f;
    private bool isGameOver = false;

    private Vector2 lastDirection = Vector2.down;
    private bool isMoving = false;

    private float gearShiftCooldown = 0f;

    void Start()
    {
        rb = GetComponent<Rigidbody2D>();
        animator = GetComponent<Animator>();

        if (winPanel != null) winPanel.SetActive(false);
        if (losePanel != null) losePanel.SetActive(false);

        currentGear = TractorGear.Neutral;
        ApplyCurrentGearSettings();

        if (animator != null)
        {
            animator.SetBool("isMoving", isMoving);
            animator.SetFloat("InputX", lastDirection.x);
            animator.SetFloat("InputY", lastDirection.y);
        }
    }

    void Update()
    {
        if (isGameOver) return;

        HandleGearShifting();

        bool isBraking = Keyboard.current != null && Keyboard.current.spaceKey.isPressed;

        Vector2 keyboardInput = Vector2.zero;
        if (Keyboard.current != null)
        {
            if (Keyboard.current.wKey.isPressed || Keyboard.current.upArrowKey.isPressed) keyboardInput.y += 1f;
            if (Keyboard.current.sKey.isPressed || Keyboard.current.downArrowKey.isPressed) keyboardInput.y -= 1f;
            if (Keyboard.current.dKey.isPressed || Keyboard.current.rightArrowKey.isPressed) keyboardInput.x += 1f;
            if (Keyboard.current.aKey.isPressed || Keyboard.current.leftArrowKey.isPressed) keyboardInput.x -= 1f;
        }

        Vector2 combinedInput = moveInput + keyboardInput;
        combinedInput.x += FPGAReceiver.inputX;
        combinedInput.y += FPGAReceiver.inputY;

        combinedInput.x = Mathf.Clamp(combinedInput.x, -1f, 1f);
        combinedInput.y = Mathf.Clamp(combinedInput.y, -1f, 1f);

        isMoving = (combinedInput != Vector2.zero) && !isBraking && (currentGear != TractorGear.Neutral);

        if (isBraking || currentGear == TractorGear.Neutral)
        {
            rb.linearVelocity = Vector2.zero;
        }
        else
        {
            Vector2 appliedMovement = combinedInput;
            if (currentGear == TractorGear.Reverse)
            {
                appliedMovement = -combinedInput;
            }
            rb.linearVelocity = appliedMovement * currentMoveSpeed;
        }

        if (animator != null)
        {
            animator.SetBool("isMoving", isMoving);

            if (isMoving)
            {
                lastDirection = combinedInput.normalized;
                animator.SetFloat("InputX", combinedInput.x);
                animator.SetFloat("InputY", combinedInput.y);
            }
            else
            {
                animator.SetFloat("InputX", lastDirection.x);
                animator.SetFloat("InputY", lastDirection.y);
            }
        }

        if (Keyboard.current != null)
        {
            if (Keyboard.current.mKey.wasPressedThisFrame) TriggerWin();
            else if (Keyboard.current.nKey.wasPressedThisFrame) TriggerLose();
        }
    }

    public void Move(InputAction.CallbackContext context)
    {
        if (isGameOver) return;
        moveInput = context.ReadValue<Vector2>();
    }

    private void HandleGearShifting()
    {
        if (gearShiftCooldown > 0)
        {
            gearShiftCooldown -= Time.deltaTime;
        }

        bool shiftUpKeyboard = Keyboard.current != null && Keyboard.current.eKey.wasPressedThisFrame;
        bool shiftDownKeyboard = Keyboard.current != null && Keyboard.current.qKey.wasPressedThisFrame;

        bool shiftUp = shiftUpKeyboard || FPGAReceiver.gearUp;
        bool shiftDown = shiftDownKeyboard || FPGAReceiver.gearDown;

        if ((shiftUp || shiftDown) && gearShiftCooldown <= 0f)
        {
            if (isReverseOnlyLevel)
            {
                if (shiftUp && currentGear == TractorGear.Neutral)
                {
                    currentGear = TractorGear.Reverse;
                }
                else if (shiftDown && currentGear == TractorGear.Reverse)
                {
                    currentGear = TractorGear.Neutral;
                }
            }
            else
            {
                if (shiftUp)
                {
                    currentGear = currentGear == TractorGear.Reverse ? TractorGear.Neutral : currentGear + 1;
                }
                else if (shiftDown)
                {
                    currentGear = currentGear == TractorGear.Neutral ? TractorGear.Reverse : currentGear - 1;
                }
            }

            ApplyCurrentGearSettings();

            FPGAReceiver.gearUp = false;
            FPGAReceiver.gearDown = false;
            gearShiftCooldown = 0.3f;
        }
    }

    private void ApplyCurrentGearSettings()
    {
        switch (currentGear)
        {
            case TractorGear.Neutral:
                currentMoveSpeed = 0f;
                UpdateGearText("N");
                break;
            case TractorGear.First:
                currentMoveSpeed = speedFirstGear;
                UpdateGearText("1");
                break;
            case TractorGear.Second:
                currentMoveSpeed = speedSecondGear;
                UpdateGearText("2");
                break;
            case TractorGear.Third:
                currentMoveSpeed = speedThirdGear;
                UpdateGearText("3");
                break;
            case TractorGear.Reverse:
                currentMoveSpeed = speedReverse;
                UpdateGearText("R");
                break;
        }
    }

    private void UpdateGearText(string gearName)
    {
        if (gearText != null) gearText.text = "Marcha: " + gearName;
    }

    private IEnumerator EndGameSequence(GameObject panelToShow, bool isWin)
    {
        isGameOver = true;
        rb.linearVelocity = Vector2.zero;

        if (animator != null) animator.SetBool("isMoving", false);
        if (panelToShow != null) panelToShow.SetActive(true);

        yield return new WaitForSeconds(waitTimeAfterEnd);

        if (isWin)
        {
            SceneManager.LoadSceneAsync(nextSceneIndex);
        }
        else
        {
            SceneManager.LoadSceneAsync(menuOrLoadingIndex);
        }
    }

    public void TriggerWin()
    {
        if (!isGameOver)
        {
            if (winSound != null) AudioSource.PlayClipAtPoint(winSound, Camera.main.transform.position);
            StartCoroutine(EndGameSequence(winPanel, true));
        }
    }

    public void TriggerLose()
    {
        if (!isGameOver)
        {
            if (loseSound != null) AudioSource.PlayClipAtPoint(loseSound, Camera.main.transform.position);
            StartCoroutine(EndGameSequence(losePanel, false));
        }
    }
}