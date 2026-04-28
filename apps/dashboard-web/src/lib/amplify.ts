import { Amplify } from "aws-amplify";

const region = process.env.NEXT_PUBLIC_COGNITO_REGION ?? "eu-west-3";
const userPoolId = process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID ?? "";
const userPoolClientId = process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID ?? "";

let configured = false;

export function configureAmplify() {
  if (configured) return;
  if (!userPoolId || !userPoolClientId) {
    console.warn(
      "Cognito env vars missing; auth will fail. " +
        "Rebuild the dashboard image with NEXT_PUBLIC_COGNITO_USER_POOL_ID and NEXT_PUBLIC_COGNITO_CLIENT_ID set.",
    );
    return;
  }
  Amplify.configure({
    Auth: {
      Cognito: {
        userPoolId,
        userPoolClientId,
        loginWith: { email: true },
      },
    },
  });
  configured = true;
}

if (typeof window !== "undefined") {
  configureAmplify();
}
