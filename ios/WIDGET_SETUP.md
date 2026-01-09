# Liflow – iOS Widget setup (WidgetKit)

Este projeto usa o plugin **home_widget** para compartilhar dados do Flutter com widgets nativos.

## 1) App Group (obrigatório)

O app e o widget precisam estar no **mesmo App Group** para acessar o mesmo `UserDefaults`.

Este repo está configurado para usar:

- `group.com.example.liflow`

Se você mudar o Bundle ID, ajuste também o App Group para algo do tipo:

- `group.<seu.bundle.id>`

E mantenha o valor **idêntico** em:

- Flutter: `HomeWidget.setAppGroupId(...)` em [lib/main.dart](../lib/main.dart)
- iOS Widget: `appGroupId` em [ios/LiflowWidget/LiflowWidget.swift](LiflowWidget/LiflowWidget.swift)

## 2) Criar o Widget Extension no Xcode

> Isso precisa ser feito em um Mac.

1. Abra `ios/Runner.xcworkspace` no Xcode
2. `File -> New -> Target...`
3. Selecione **Widget Extension** e nomeie como **LiflowWidget**
4. Marque **Include Configuration Intent** = off (não precisamos)
5. Certifique-se que o widget suporta apenas **systemSmall**

## 3) Conectar os arquivos do widget

Use o conteúdo deste repo como base:

- [ios/LiflowWidget/LiflowWidget.swift](LiflowWidget/LiflowWidget.swift)
- [ios/LiflowWidget/Info.plist](LiflowWidget/Info.plist)

Você pode:
- substituir o Swift gerado pelo Xcode pelo arquivo acima, ou
- mover/copiar este arquivo para dentro do target do Widget.

## 4) Habilitar App Groups nos dois targets

No Xcode, para **Runner** e para **LiflowWidget**:

- `Signing & Capabilities -> + Capability -> App Groups`
- Adicione/seleciona `group.com.example.liflow`

## 5) Como o widget escolhe a “tarefa atual”

O Flutter salva uma lista JSON de tarefas do dia (pendentes) na key:

- `liflow_widget_day_tasks_json`

O widget pega a tarefa “atual” assim:

- entre `time[i]` e `time[i+1]` mostra `i`
- antes da primeira, mostra a primeira
- depois da última, mostra a última

Ele agenda a próxima atualização exatamente no horário da próxima tarefa.
