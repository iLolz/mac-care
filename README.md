# Mac Care

Limpador de armazenamento open source para macOS. Analisa o disco periodicamente, mostra quanto espaço pode ser recuperado e avisa quando o espaço livre fica abaixo de um limite que você escolhe (em % ou em GB).

> Open-source storage cleaner for macOS: scans your disk, cleans safe-to-remove files and alerts you when free space runs low.

## Status

Em desenvolvimento. Roadmap:

1. **Análise do disco** — varredura das categorias limpáveis e interface principal *(em andamento)*
2. **Limpeza segura** — prévia, confirmação, envio para a Lixeira e exclusões
3. **Monitoramento e alertas** — checagem em segundo plano, notificações e widget
4. **Distribuição** — assinatura, notarização e releases em `.dmg`

## O que o Mac Care analisa

| Categoria | Onde |
|---|---|
| Caches de apps | `~/Library/Caches` |
| Logs | `~/Library/Logs` |
| Lixeira | `~/.Trash` |
| Downloads antigos | `~/Downloads` (mais de 30 dias) |
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` |
| Suporte a dispositivos do Xcode | `~/Library/Developer/Xcode/*DeviceSupport` |
| Caches do Simulador | `~/Library/Developer/CoreSimulator/Caches` |
| Caches de ferramentas de dev | `~/.npm/_cacache`, `~/.gradle/caches` |
| node_modules | pastas de projetos como `~/Developer`, `~/Projects` |

A análise é somente leitura. Nada é apagado sem sua confirmação.

## Compilando

Requisitos: macOS 14+, Xcode 16+ e [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open MacCare.xcodeproj
```

A lógica de análise fica no pacote `CleanerKit`, testável sem o app:

```sh
swift test --package-path CleanerKit
```

### Acesso Total ao Disco

Para ler pastas protegidas (como a Lixeira), conceda **Acesso Total ao Disco** em Ajustes do Sistema › Privacidade e Segurança. O app mostra um aviso com atalho quando o acesso está faltando.

### Barra de menus e inicialização

Ao fechar a janela, o Mac Care continua na barra de menus: o painel mostra o espaço livre, quanto dá para recuperar e atalhos para analisar de novo ou reabrir o app. O app também abre ao iniciar sessão (ativado na primeira execução). As duas opções podem ser desligadas em **Ajustes › Geral**; com a barra de menus desligada, fechar a janela encerra o app.

## Licença

[MIT](LICENSE)
