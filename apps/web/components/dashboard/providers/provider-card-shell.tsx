import { ProviderSpec } from "@schema";
import {
  fetchDecryptedSecrets,
  SyncProvidersRow,
} from "@/lib/actions/dashboard";
import ProviderCard from "@/components/dashboard/providers/provider-card";
import { providerSecrets } from "@db";

type Props = {
  userProviders: SyncProvidersRow[];
  spec: ProviderSpec;
};

export default async function ProviderCardShell({
  userProviders,
  spec,
}: Props) {
  const userProvider = userProviders.find((p) => p.type === spec.key);

  // Guard: if no provider configured, render empty state without fetching secrets
  // Fix: String(undefined) was passing "undefined" as UUID causing DB error
  if (!userProvider) {
    return (
      <ProviderCard
        spec={spec}
        userProvider={undefined}
        decryptedSecret={undefined}
      />
    );
  }

  const [decryptedSecret] = await fetchDecryptedSecrets({
    linkTable: providerSecrets,
    foreignCol: providerSecrets.providerId,
    secretIdCol: providerSecrets.secretId,
    parentId: userProvider.id,
  });

  return (
    <ProviderCard
      spec={spec}
      userProvider={userProvider}
      decryptedSecret={decryptedSecret}
    />
  );
}
