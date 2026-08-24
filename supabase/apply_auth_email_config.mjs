#!/usr/bin/env node
// Applique les templates d'e-mail (FR) et l'URL de deep link au projet
// Supabase live via la Management API — PATCH ciblé sur une poignée de
// champs nommés explicitement, jamais un remplacement en bloc de la config
// Auth (contrairement à `supabase config push`, qui pousse tout un
// `config.toml` et risquerait d'écraser des réglages live invisibles d'ici :
// SMTP personnalisé, providers OAuth, etc. — voir la discussion du 2026-08-23).
//
// Usage :
//   export SUPABASE_ACCESS_TOKEN="<jeton personnel, https://supabase.com/dashboard/account/tokens>"
//   node supabase/apply_auth_email_config.mjs            # dry-run : affiche le diff, ne modifie rien
//   node supabase/apply_auth_email_config.mjs --apply    # applique réellement le PATCH
//
// Ce script ne doit être lancé QUE par le porteur de projet lui-même (jeton
// personnel Supabase requis) — jamais par Claude Code, qui ne doit jamais
// voir ce jeton.

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const PROJECT_REF = process.env.SUPABASE_PROJECT_REF || 'elrxlhhmkjfcbmiloilp';
const ACCESS_TOKEN = process.env.SUPABASE_ACCESS_TOKEN;
const AUTH_CALLBACK_URL = 'com.attijaniya.at_tijaniya://login-callback';
const APPLY = process.argv.includes('--apply');

if (!ACCESS_TOKEN) {
  console.error(
    'SUPABASE_ACCESS_TOKEN manquant. Générez un jeton personnel sur ' +
      'https://supabase.com/dashboard/account/tokens puis :\n' +
      '  export SUPABASE_ACCESS_TOKEN="sbp_..."',
  );
  process.exit(1);
}

const API_BASE = `https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth`;

async function main() {
  console.log(`Lecture de la config Auth actuelle du projet ${PROJECT_REF}...`);
  const getRes = await fetch(API_BASE, {
    headers: { Authorization: `Bearer ${ACCESS_TOKEN}` },
  });
  if (!getRes.ok) {
    throw new Error(`Échec de lecture (GET ${getRes.status}) : ${await getRes.text()}`);
  }
  const current = await getRes.json();

  // Sauvegarde locale avant toute modification — jamais commit (voir .gitignore).
  const backupDir = path.join(__dirname, '.backups');
  mkdirSync(backupDir, { recursive: true });
  const backupPath = path.join(backupDir, `auth_config_${Date.now()}.json`);
  writeFileSync(backupPath, JSON.stringify(current, null, 2));
  console.log(`Config actuelle sauvegardée dans ${backupPath}`);

  const confirmationHtml = readFileSync(path.join(__dirname, 'templates', 'confirmation.html'), 'utf8');
  const recoveryHtml = readFileSync(path.join(__dirname, 'templates', 'recovery.html'), 'utf8');

  // `uri_allow_list` est une chaîne CSV côté API — on complète sans écraser
  // les entrées déjà présentes (ex. redirections déjà configurées ailleurs).
  const existingUrls = (current.uri_allow_list || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  const mergedUrls = existingUrls.includes(AUTH_CALLBACK_URL)
    ? existingUrls
    : [...existingUrls, AUTH_CALLBACK_URL];

  // Le Site URL ne sert que de secours quand aucun `redirectTo` explicite
  // n'est passé (ce n'est plus le cas ici, voir SupabaseConfig.authCallbackUrl
  // et auth_screen.dart) — on ne le change que s'il ressemble encore au
  // placeholder de création de projet, pour ne jamais écraser une valeur
  // déjà choisie intentionnellement.
  const looksLikeDefaultPlaceholder =
    !current.site_url || /localhost|127\.0\.0\.1/i.test(current.site_url);
  const newSiteUrl = looksLikeDefaultPlaceholder ? AUTH_CALLBACK_URL : current.site_url;

  // Deux PATCH séparés plutôt qu'un seul : sur un projet gratuit sans SMTP
  // personnalisé, Supabase refuse TOUTE modification des templates
  // (mailer_*) en bloc, y compris les champs qui n'ont rien à voir avec
  // l'e-mail (site_url, uri_allow_list) si on les envoie dans la même
  // requête. Séparer permet à la redirection de passer même quand les
  // templates restent bloqués.
  const redirectPatch = {
    uri_allow_list: mergedUrls.join(','),
    ...(newSiteUrl !== current.site_url ? { site_url: newSiteUrl } : {}),
  };
  const templatesPatch = {
    mailer_subjects_confirmation: 'Confirmez votre inscription à At-Tijaniya',
    mailer_templates_confirmation_content: confirmationHtml,
    mailer_subjects_recovery: 'Réinitialisez votre mot de passe At-Tijaniya',
    mailer_templates_recovery_content: recoveryHtml,
  };

  console.log('\n--- Changements proposés : redirection (deep link) ---');
  console.log('uri_allow_list:', JSON.stringify(current.uri_allow_list || ''), '->', JSON.stringify(redirectPatch.uri_allow_list));
  if ('site_url' in redirectPatch) {
    console.log('site_url:', JSON.stringify(current.site_url), '->', JSON.stringify(redirectPatch.site_url));
  } else {
    console.log('site_url: inchangé (', JSON.stringify(current.site_url), '— ne ressemble pas à un placeholder, laissé tel quel)');
  }

  console.log('\n--- Changements proposés : templates d\'e-mail (FR) ---');
  console.log('mailer_subjects_confirmation:', JSON.stringify(current.mailer_subjects_confirmation), '->', JSON.stringify(templatesPatch.mailer_subjects_confirmation));
  console.log('mailer_subjects_recovery:', JSON.stringify(current.mailer_subjects_recovery), '->', JSON.stringify(templatesPatch.mailer_subjects_recovery));
  console.log('mailer_templates_confirmation_content: (voir supabase/templates/confirmation.html,', confirmationHtml.length, 'caractères)');
  console.log('mailer_templates_recovery_content: (voir supabase/templates/recovery.html,', recoveryHtml.length, 'caractères)');
  console.log('\nNote : si le projet est sur le plan gratuit avec l\'expéditeur par défaut, Supabase');
  console.log('refuse la modification des templates tant qu\'aucun SMTP personnalisé n\'est configuré');
  console.log('(Authentication > Emails > SMTP Settings). Ce script tentera quand même, et signalera');
  console.log('clairement l\'échec le cas échéant sans bloquer le reste.');

  if (!APPLY) {
    console.log('\nDry-run (aucune modification envoyée). Relancez avec --apply pour appliquer ces changements.');
    return;
  }

  async function patch(name, body) {
    if (Object.keys(body).length === 0) {
      console.log(`\n${name} : rien à appliquer.`);
      return true;
    }
    console.log(`\nApplication : ${name}...`);
    const res = await fetch(API_BASE, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      console.error(`Échec (${name}, ${res.status}) : ${await res.text()}`);
      return false;
    }
    console.log(`${name} : OK.`);
    return true;
  }

  const redirectOk = await patch('Redirection (site_url / uri_allow_list)', redirectPatch);
  const templatesOk = await patch("Templates d'e-mail (FR)", templatesPatch);

  console.log('\n--- Résumé ---');
  console.log('Redirection (deep link) :', redirectOk ? 'appliquée' : 'ÉCHEC — voir le message ci-dessus');
  console.log("Templates d'e-mail (FR) :", templatesOk ? 'appliqués' : 'ÉCHEC — voir le message ci-dessus (probablement le plan gratuit + expéditeur par défaut, voir README)');
}

main().catch((error) => {
  console.error('Erreur :', error.message);
  process.exit(1);
});
