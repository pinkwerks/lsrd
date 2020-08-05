using HoloToolkit.Unity;
using System.Collections;
using UnityEngine;
using UnityEngine.VR.WSA.Input;

public class Kontroller : MonoBehaviour
{
    public Material SpatialMappingMaterial;
    public GameObject Oscillator;
    public AudioSource tapAudio;
    GestureRecognizer recognizer;
    public GameObject debugSR;
    public Material[] Materials;
    public float speed;
    public float minspeed = .1f;
    public float maxspeed = 10.0f;
    public float magnitude = 20.0f;
    public GameObject SMCam;
    //public bool hideDebugSR;
    //public int CurrentMaterialIndex = 0;
    public bool randomizeOnPlay = true;

    bool run = true;
    bool RunPauseSpatialMappingUpdate = true;

    int Epicenter;
    int radius;
    int wavea;
    int waveb;
    int wavec;
    int reset;
    int normalmix;
    int normalmixb;
    //int wavewback;
    //int wavewfront;
    //int waveoffset;

    //float lastHitTime;

    Animator OscAnim;

    IEnumerator WaitAndPrint(float seconds, bool repeat)
    {
        while (run)
        {
            yield return new WaitForSeconds(seconds);
            Debug.Log("WaitAndPrint Spatial Mapping Update");
            Debug.Log(Time.time);
            if (!repeat)
                run = false;
        }
    }

    IEnumerator PauseSpatialMappingUpdate(float seconds)
    {
        // TODO XXX
        while (RunPauseSpatialMappingUpdate)
        {
            yield return new WaitForSeconds(seconds);
            run = RunPauseSpatialMappingUpdate;
        }
    }

    void Start()
    {
        Epicenter = Shader.PropertyToID("_Center");
        radius = Shader.PropertyToID("_Radius");
        wavea = Shader.PropertyToID("_WaveSizeA");
        waveb = Shader.PropertyToID("_WaveSizeB");
        wavec = Shader.PropertyToID("_WaveSizeC");

        //normalmix = Shader.PropertyToID("_NormalMix");
        normalmixb = Shader.PropertyToID("_NormalMixB");

        reset = Animator.StringToHash("Reset");

        // Set up a GestureRecognizer to detect Select gestures.
        recognizer = new GestureRecognizer();
        recognizer.TappedEvent += OnSelect;

        recognizer.StartCapturingGestures();

        // reset animations
        OscAnim = Oscillator.GetComponent<Animator>();

#if UNITY_EDITOR
        OscAnim.SetTrigger(reset);
        OscAnim.speed = 1.0f;
        SpatialMappingMaterial.SetFloat(normalmixb, .420f);

#else
        // help make sure we don't show our debugging SR in the build.
        debugSR.SetActive(false);
        randomizeOnPlay = true;
#endif

        //StartCoroutine(WaitAndPrint(2, false));

        if (randomizeOnPlay)
        {
            SwapShaders();
        }

    }

    public void UpdateMeshRendererMaterial()
    {
#if UNITY_EDITOR
        // update the material in the editor when in unity
        var meshRenderers = debugSR.GetComponentsInChildren<MeshRenderer>();
        foreach (MeshRenderer m in meshRenderers)
        {
            m.sharedMaterial = SpatialMappingMaterial;
        }
#else
		// Runtime
		// assign a random material to the spatial mapping
		SMCam.GetComponent<SpatialMappingManager>().SurfaceMaterial = SpatialMappingMaterial;
#endif
    }

    public void SwapShaders()
    {
        int choice = Random.Range(0, Materials.Length);
        Material chosenMaterial = Materials[choice];
        SpatialMappingMaterial = chosenMaterial;

        UpdateMeshRendererMaterial();
    }

    // Called by GazeGestureManager when the user performs a Select gesture
    void OnSelect(InteractionSourceKind source, int tapCount, Ray headRay)
    {
        RaycastHit hitInfo;

        if (Physics.Raycast(headRay, out hitInfo, 30.0f))
        {
            // Set the overall pace of the effect
            speed = Random.Range(minspeed, maxspeed);

            OscAnim.speed = speed;

            // tweak audio accordingly
            tapAudio.pitch = speed;

            var clickPosition = new Vector4(hitInfo.point.x, hitInfo.point.y, hitInfo.point.z, 0);

            SwapShaders();

            SpatialMappingMaterial.SetVector(Epicenter, clickPosition);

            tapAudio.transform.position = hitInfo.point;
            tapAudio.Play();

            SpatialMappingMaterial.SetFloat(wavea, Random.Range(2f, 10f));
            SpatialMappingMaterial.SetFloat(waveb, Random.Range(2f, 10f));
            SpatialMappingMaterial.SetFloat(wavec, Random.Range(2f, 10f));

            // SRMat.SetFloat(normalmix, Random.Range(0, 1));
            SpatialMappingMaterial.SetFloat(normalmixb, Random.Range(0f, 1f));

            OscAnim.SetTrigger(reset);

            // pause the spatial mapping update for awhile
            // the animation loops, we just wanted to avoid
            // swapping artifacts for a few seconds while
            // the effect is close

            // TODO

            //StartCoroutine(PauseSpatialMappingUpdate(1));


        }
    }

    // Update is called once per frame
    void Update()
    {
        // Use the oscilator values
        // this is wacky
        // i'm hijacking the oscillator's transform x position as an animated variable
        // we don't render the oscillator game object
        // i record the changing values in that transform for reasons below
        // q1: how is transform.x animated? 
        // a1: via the animator, which points to a motion curve wubwub
        // q2: why not animate the shader parameter directly?
        // a2: cause i couldn't figure out how, so i pass it through transform.x of an invisible object
        // a2: it lets me point many interfaces to this one value. a bit like a global variable
        // maybe a pub-sub event system is better but whatever.
        SpatialMappingMaterial.SetFloat(radius, Oscillator.transform.position.x * magnitude);
    }

    // UWP thing
    // VOODOO see if fixes SR not coming up between launches sometimes
    void OnApplicationPause(bool pause)
    {
        Application.Quit();
    }

    void OnDisable()
    {
        run = false;
    }

}
