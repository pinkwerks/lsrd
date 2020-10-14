using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Microsoft.MixedReality.Toolkit.Input;

public class Kontroller : MonoBehaviour
{
    public Material SpatialMappingMaterial;
    public GameObject Oscillator;
    public AudioSource tapAudio;
    public Material[] Materials;
    public float speed;
    public float minspeed = .1f;
    public float maxspeed = 10.0f;
    public float magnitude = 20.0f;
    public bool randomizeOnPlay = true;

    UnityEngine.XR.WSA.Input.GestureRecognizer recognizer;
    int Epicenter;
    int radius;
    int wavea;
    int waveb;
    int wavec;
    int reset;
    int normalmix;
    int normalmixb;
    Animator OscAnim;

    void OnEnable()
    {
        Epicenter = Shader.PropertyToID("_Center");
        radius = Shader.PropertyToID("_Radius");
        wavea = Shader.PropertyToID("_WaveSizeA");
        waveb = Shader.PropertyToID("_WaveSizeB");
        wavec = Shader.PropertyToID("_WaveSizeC");

        //normalmix = Shader.PropertyToID("_NormalMix");
        normalmixb = Shader.PropertyToID("_NormalMixB");

        reset = Animator.StringToHash("Reset");

        // reset animations
        OscAnim = Oscillator.GetComponent<Animator>();

        OscAnim.SetTrigger(reset);
        OscAnim.speed = 1.0f;
        SpatialMappingMaterial.SetFloat(normalmixb, .420f);

        SpatialMappingMaterial.SetVector(Epicenter, Vector3.zero);


        if (randomizeOnPlay)
        {
            SwapShaders();
        }
    }

    public void UpdateMeshRendererMaterial()
    {
#if UNITY_EDITOR
        // update the material in the editor when in unity
        //var meshRenderers = debugSR.GetComponentsInChildren<MeshRenderer>();
        //foreach (MeshRenderer m in meshRenderers)
        //{
        //    m.sharedMaterial = SpatialMappingMaterial;
        //}
#else
		// Runtime
		// assign a random material to the spatial mapping
		//SMCam.GetComponent<SpatialMappingManager>().SurfaceMaterial = SpatialMappingMaterial;
#endif
    }

    public void SwapShaders()
    {
        int choice = Random.Range(0, Materials.Length);
        Material chosenMaterial = Materials[choice];
        SpatialMappingMaterial = chosenMaterial;

        UpdateMeshRendererMaterial();
    }

    // Update is called once per frame
    void Update()
    {
        // Use the gameobject values
        // this is wacky
        // i'm hijacking the gameobjects's transform x position as an animated variable
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

    public void OnPointerClicked(MixedRealityPointerEventData eventData)
    {
        // Set the overall pace of the effect
        speed = Random.Range(minspeed, maxspeed);

        OscAnim.speed = speed;

        // tweak audio accordingly
        tapAudio.pitch = speed;

        //SwapShaders();

        SpatialMappingMaterial.SetVector(Epicenter, eventData.Pointer.BaseCursor.Position);

        tapAudio.transform.position = eventData.Pointer.BaseCursor.Position;
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

    // UWP thing
    // VOODOO see if fixes SR not coming up between launches sometimes
    //void OnApplicationPause(bool pause)
    //{
    //    Application.Quit();
    //}

    //void OnDisable()
    //{
    //    run = false;
    //}
}
