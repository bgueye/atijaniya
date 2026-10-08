# Règles de conservation de code pour la version de publication (R8).
#
# Flutter réduit et renomme le code Android en `release`. Le plugin
# `flutter_local_notifications` enregistre et relit chaque rappel programmé
# avec Gson, qui a besoin des informations de types génériques et des noms de
# champs d'origine. Sans ces règles, la programmation d'un rappel échoue en
# silence dans la version signée (« Missing type parameter ») alors qu'elle
# fonctionne en débogage : constaté le 2026-10-08, plus aucun rappel de wird
# depuis l'installation de la version de publication le 2026-10-06.
# Règles reprises de la documentation du plugin (« Release build
# configuration ») et de Gson.

-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Les rappels programmés sont stockés sur l'appareil sous les noms de champs
# de ces classes : ils doivent rester identiques d'une version à l'autre,
# sinon une mise à jour ne saurait plus relire les rappels de la précédente.
-keep class com.dexterous.** { *; }
