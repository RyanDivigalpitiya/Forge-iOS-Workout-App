# Forge-iOS-Workout-App

Welcome to my weight-lifting workout app for iOS! This application that I am developing is a sideproject of mine where I'll be experimenting with large langauge models (LLM), specifically to see if I can use [QLoRA](https://huggingface.co/blog/4bit-transformers-bitsandbytes) to deploy an LLM to my iPhone. 
I will be attempting to locally deploy a QLoRA large language model using Apple's CoreML framework to generate workout plans on the fly - details can be found here: [ryan-div.com/workout-app](https://www.ryan-div.com/side-projects-freelancing-gigs/watchos-workout-app) 

## Goals:

- **Natural Language Processing**: One of the key features of the workout app is its ability to understand natural language inputs. For example, if you have a workout routine typed up in your iOS's Notes app, my app will interpret it and convert it into a structured workout plan managed by the app. 

- **Local Language Model**: The plan is to attempt to use a locally-deployed Large Language Model (LLM) for processing your input and generating workout plans. This ensures fast processing and respects user privacy, as all the processing happens on your device, and your data never leaves it. 

- **Server-side Language Model**: If Apple's CoreML cannot support QLoRA (meaning, I cannot deploy the LLM to my iPhone), then I will pivot to using a server-side model that the app will for it's features that rely on workout plan generation.

- **User-friendly Interface**: Built using SwiftUI, the app provides a smooth, intuitive, and minimal user experience, making it easy to plan and track your workouts.

## How To Use

1. **Plan Generation**: Select the muscle group you wish to focus on along with your fitness level, and the app will generate a comprehensive workout plan targeting those muscles.

2. **Convert From Notes**: Simply upload a workout routine you have written down in iOS's Notes app. Forge's LLM will interpret your notes and convert them into a structured workout plan fully managed and tracked by the app.

## Approach to building my app:

![Figure from ryan-div.com](https://uploads-ssl.webflow.com/5ee2bc2fae275c68fb94f279/64adc31b596ad0d0db574a52_phone%20daig.png)

## **Stay tuned for final release :)**

## Contributing

If you've had any experience deploying LLMS using QLorA onto iOS devices, I'd love to hear from you and even collaborate with you! For major changes, please open an issue first to discuss how you would like to collaborate!

## License

[MIT](https://choosealicense.com/licenses/mit/)
