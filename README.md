# Liflow
Aplicativo pessoal para cadastro e organização de rotinas diárias/semanais com atividades, subtarefas, lembretes e widget de tarefas (Android).

## Rodar o projeto
- `flutter pub get`
- `flutter run`

## Criar e conectar o Firebase (sem autenticação)
Você ainda não tem um projeto Firebase criado; siga estes passos:

1) Criar o projeto no console
- Acesse o Firebase Console e crie um projeto (ex.: `liflow`).
- Ative o Cloud Firestore (modo de teste para uso pessoal, depois você pode ajustar regras).

2) Instalar e usar o FlutterFire CLI
- Instale: `dart pub global activate flutterfire_cli`
- Faça login no Google (se necessário): `firebase login`
- Na raiz do projeto, rode: `flutterfire configure`
	- Selecione o projeto criado
	- Selecione Android (e iOS se quiser)

Isso vai gerar o arquivo `lib/firebase_options.dart` e também baixar/criar os arquivos nativos
(`android/app/google-services.json` e `ios/Runner/GoogleService-Info.plist`).

3) Inicializar o Firebase no app
- No `lib/main.dart`, inicialize o Firebase com `Firebase.initializeApp(...)` usando `firebase_options.dart`.

## Widget Android (base)
Este repo já inclui uma base mínima do widget em Android:
- Layout: `android/app/src/main/res/layout/task_widget.xml`
- Provider: `android/app/src/main/kotlin/com/example/liflow/TaskWidgetProvider.kt`
- Info: `android/app/src/main/res/xml/task_widget_info.xml`

O widget vai ler um snapshot persistido pelo app (via plugin `home_widget`).
Próximo passo: implementar a pipeline de snapshot do dia (tarefas não concluídas até um horário) e ações de marcar como concluída.
