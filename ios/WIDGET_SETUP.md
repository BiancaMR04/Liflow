# Liflow - iOS Widget setup (WidgetKit)

Este projeto usa o plugin `home_widget` para compartilhar dados do Flutter com
um widget nativo em SwiftUI.

## 1. Target do widget

O target `LiflowWidget` ja esta incluido em `ios/Runner.xcodeproj` e e embutido
no app `Runner`.

No Mac, abra `ios/Runner.xcworkspace`, rode `pod install` se o Flutter nao fizer
isso automaticamente, e faca o build pelo target `Runner`.

## 2. App Group

O app e o widget precisam estar no mesmo App Group para acessar o mesmo
`UserDefaults`.

Valor configurado no projeto:

- `group.com.example.liflow`

Mantenha o mesmo valor em:

- `lib/main.dart`
- `lib/services/widget_interactivity.dart`
- `ios/LiflowWidget/LiflowWidget.swift`
- `ios/Runner/Runner.entitlements`
- `ios/LiflowWidget/LiflowWidget.entitlements`

No Xcode, confirme em `Signing & Capabilities` que os targets `Runner` e
`LiflowWidget` tem a capability `App Groups` com esse mesmo grupo.

## 3. Check pelo widget

Em iOS 17 ou superior, o circulo de check do widget usa `BackgroundIntent` e
chama o callback Dart registrado por `HomeWidget.registerInteractivityCallback`.

Fluxo:

- O widget monta `liflow://widget/markDone?...`
- `ios/Runner/BackgroundIntent.swift` chama `HomeWidgetBackgroundWorker`
- `lib/services/widget_interactivity.dart` marca a atividade como concluida
- O snapshot do widget e atualizado para a tarefa sair do card

## 4. Como o widget escolhe a tarefa atual

O Flutter salva as tarefas pendentes do dia na key:

- `liflow_widget_day_tasks_json`

O widget escolhe a tarefa atual assim:

- antes da primeira tarefa, mostra a primeira
- entre `time[i]` e `time[i+1]`, mostra `i`
- depois da ultima tarefa, mostra a ultima

Ele agenda a proxima atualizacao no horario da proxima tarefa.
