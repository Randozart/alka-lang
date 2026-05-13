const vscode = require('vscode');
const { LanguageClient } = require('vscode-languageclient/node');
const path = require('path');
const fs = require('fs');

let lspClient = null;

function activate(context) {
    console.log('Alka Gloss: activating...');
    const lspPath = findLspBinary();

    // Register restart command (always available)
    context.subscriptions.push(
        vscode.commands.registerCommand('alka.restart', () => restartLsp())
    );

    if (!lspPath) {
        vscode.window.showInformationMessage(
            'Alka LSP binary not found. Build with: zig build install',
            'Build Now'
        ).then(s => { if (s === 'Build Now') buildLsp(); });
        registerBasicFeatures(context);
        return;
    }

    const serverOptions = { command: lspPath, args: [], options: { stdio: 'pipe' } };
    const clientOptions = {
        documentSelector: [{ scheme: 'file', language: 'alka' }, { scheme: 'file', language: 'alkavl' }],
        synchronize: { fileEvents: vscode.workspace.createFileSystemWatcher('**/*.{alka,alkavl}') },
        diagnosticCollectionName: 'alka-lsp'
    };

    lspClient = new LanguageClient('alka-lsp', 'Alka Gloss', serverOptions, clientOptions);

    context.subscriptions.push(
        vscode.commands.registerCommand('alka.compile', () => compileCurrentFile()),
        vscode.commands.registerCommand('alka.suggest', () => promptSuggest()),
        vscode.commands.registerCommand('alka.probe', () => runInTerminal('zig build run -- --probe-all --vials'))
    );

    context.subscriptions.push(lspClient.start());
    console.log('Alka Gloss: activated with LSP');
}

function deactivate() {
    if (lspClient) lspClient.stop();
    console.log('Alka Gloss: deactivated');
}

function restartLsp() {
    if (lspClient) {
        vscode.window.showInformationMessage('Restarting Alka LSP...');
        lspClient.stop().then(() => {
            lspClient = null;
            // Re-activate by re-running activate
            // The old client is disposed, start a fresh one
            const lspPath = findLspBinary();
            if (!lspPath) {
                vscode.window.showWarningMessage('Alka LSP binary not found after restart');
                return;
            }
            const serverOptions = { command: lspPath, args: [], options: { stdio: 'pipe' } };
            const clientOptions = {
                documentSelector: [{ scheme: 'file', language: 'alka' }, { scheme: 'file', language: 'alkavl' }],
                synchronize: { fileEvents: vscode.workspace.createFileSystemWatcher('**/*.{alka,alkavl}') },
                diagnosticCollectionName: 'alka-lsp'
            };
            lspClient = new LanguageClient('alka-lsp', 'Alka Gloss', serverOptions, clientOptions);
            lspClient.start();
            vscode.window.showInformationMessage('Alka LSP restarted');
        });
    } else {
        vscode.window.showWarningMessage('Alka LSP is not running');
    }
}

function findLspBinary() {
    const ws = vscode.workspace.workspaceFolders?.[0]?.uri?.fsPath;
    if (!ws) return null;
    try {
        const cache = path.join(ws, '.zig-cache', 'o');
        if (fs.existsSync(cache)) {
            for (const d of fs.readdirSync(cache)) {
                const p = path.join(cache, d, 'alka-lsp');
                if (fs.existsSync(p)) return p;
            }
        }
    } catch (e) {}
    for (const c of [path.join(ws, 'zig-out', 'bin', 'alka-lsp'), '/usr/local/bin/alka-lsp', '/usr/bin/alka-lsp']) {
        if (fs.existsSync(c)) return c;
    }
    return null;
}

function buildLsp() {
    const ws = vscode.workspace.workspaceFolders?.[0]?.uri?.fsPath;
    if (!ws) return;
    const t = vscode.window.createTerminal('Alka Build');
    t.sendText(`cd "${ws}" && zig build install`);
    t.show();
}

function registerBasicFeatures(context) {
    context.subscriptions.push(
        vscode.commands.registerCommand('alka.compile', () => vscode.window.showWarningMessage('Build alka-lsp first: zig build install')),
        vscode.commands.registerCommand('alka.suggest', () => vscode.window.showWarningMessage('Build alka-lsp first: zig build install')),
        vscode.commands.registerCommand('alka.probe', () => runInTerminal('alka --probe-all --vials'))
    );
}

function compileCurrentFile() {
    const editor = vscode.window.activeTextEditor;
    if (!editor || editor.document.languageId !== 'alka') {
        return vscode.window.showWarningMessage('Open an .alka file to compile');
    }
    const filePath = editor.document.uri.fsPath;
    const vialPath = filePath.replace(/\.alka$/, '.alkavl');
    if (!fs.existsSync(vialPath)) {
        return vscode.window.showWarningMessage(`No Vial found: ${vialPath}`);
    }
    runInTerminal(`zig build run -- "${filePath}" "${vialPath}"`);
}

function promptSuggest() {
    vscode.window.showInputBox({ prompt: 'What do you want Alka to do?', placeHolder: 'e.g., transfer data' })
        .then(goal => {
            if (goal) runInTerminal(`zig run build/pharmacopia_build.zig -- pharmacopia.json suggest "${goal}"`);
        });
}

function runInTerminal(cmd) {
    const ws = vscode.workspace.workspaceFolders?.[0]?.uri?.fsPath;
    if (!ws) return;
    const t = vscode.window.createTerminal('Alka');
    t.sendText(`cd "${ws}" && ${cmd}`);
    t.show();
}

module.exports = { activate, deactivate };
