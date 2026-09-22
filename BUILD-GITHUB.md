# Build no GitHub Actions

Este projeto é compilado no GitHub Actions usando `macos-15`, sem Xcode project e sem target `3105`. O identificador `3105-unsigned.ipa` é somente o nome do arquivo final; o aplicativo é obtido da IPA-base fornecida ao workflow.

## Preparação

Coloque uma IPA-base autorizada na raiz do repositório com o nome:

```text
IPA-base.ipa
```

Não é necessário renomear o aplicativo interno para `3105`. O workflow localiza automaticamente a única pasta `Payload/*.app` e lê `CFBundleExecutable` do `Info.plist`.

Por segurança e por causa do tamanho dos arquivos, não incluí uma IPA-base neste projeto. A IPA deve ser uma versão compatível com o tweak e você deve ter autorização para modificá-la e redistribuí-la.

## Fluxo executado

1. O runner `macos-15` verifica se `IPA-base.ipa` é um ZIP válido, se contém `Payload/` e se há exatamente uma aplicação.
2. O workflow instala Theos, `ldid`, `dpkg`, `xz` e compila `insert_dylib`.
3. Theos compila o tweak Objective-C e gera o pacote `.deb`.
4. O `.dylib` e o plist do pacote são copiados para a aplicação extraída.
5. `insert_dylib` adiciona `@executable_path/FilzaApplySandboxExt.dylib` ao executável identificado no `Info.plist`.
6. A assinatura ad hoc é aplicada com `ldid` aos binários modificados.
7. A estrutura ZIP e a presença do dylib são verificadas.
8. O arquivo final é publicado em **Actions → Artifacts** com o nome `3105-unsigned` e arquivo `3105-unsigned.ipa`.

## Usar outra localização da IPA-base

Ao executar manualmente por **Actions → Build modified IPA (Theos) → Run workflow**, informe o caminho relativo da IPA no campo `ipa_base_path`. O valor padrão é `IPA-base.ipa`.

## Artefatos

O workflow publica dois artefatos:

- `3105-unsigned`: a IPA modificada final;
- `FilzaApplySandboxExt-theos-deb`: o pacote `.deb` do Theos para diagnóstico.

A IPA é **unsigned** no sentido de não usar um certificado de distribuição da Apple. A assinatura ad hoc feita por `ldid` não substitui a assinatura necessária para instalar o aplicativo em um dispositivo; essa etapa depende do método de instalação e da conta/certificado que você estiver autorizado a usar.

## Observações

O arquivo `Makefile` já inclui os fontes de `XPF/external/ChOma`, que precisam permanecer presentes no repositório. O workflow não executa `xcodebuild` e não procura `ThreeOneOSFive.xcodeproj` nem um target `3105`.
