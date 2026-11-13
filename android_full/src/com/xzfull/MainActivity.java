package com.xzfull;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.ClipData;
import android.content.DialogInterface;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.DocumentsContract;
import android.provider.MediaStore;
import android.provider.OpenableColumns;
import android.util.Log;
import android.view.View;
import android.webkit.MimeTypeMap;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import org.tukaani.xz.LZMA2Options;
import org.tukaani.xz.XZInputStream;
import org.tukaani.xz.XZOutputStream;

import net.lingala.zip4j.ZipFile;
import net.lingala.zip4j.model.FileHeader;
import net.lingala.zip4j.model.ZipParameters;
import net.lingala.zip4j.model.enums.AesKeyStrength;
import net.lingala.zip4j.model.enums.CompressionLevel;
import net.lingala.zip4j.model.enums.CompressionMethod;
import net.lingala.zip4j.model.enums.EncryptionMethod;

import org.apache.commons.compress.archivers.sevenz.SevenZArchiveEntry;
import org.apache.commons.compress.archivers.sevenz.SevenZFile;
import org.apache.commons.compress.archivers.sevenz.SevenZMethod;
import org.apache.commons.compress.archivers.sevenz.SevenZMethodConfiguration;
import org.apache.commons.compress.archivers.sevenz.SevenZOutputFile;
import org.apache.commons.compress.archivers.tar.TarArchiveEntry;
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream;
import org.apache.commons.compress.archivers.tar.TarArchiveOutputStream;
import org.apache.commons.compress.compressors.bzip2.BZip2CompressorInputStream;
import org.apache.commons.compress.compressors.bzip2.BZip2CompressorOutputStream;
import org.apache.commons.compress.compressors.gzip.GzipCompressorInputStream;
import org.apache.commons.compress.compressors.gzip.GzipCompressorOutputStream;

import com.github.junrar.Archive;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

/**
 * XZ 完整压缩 早期测试版 0.1 - 安卓完整版
 * 功能（对齐 Windows CMD 核心）:
 *   压缩: xz(单文件) / 7z(多文件/文件夹,可加密) / zip(多文件/文件夹,AES-256 加密)
 *         tar.xz(多文件/文件夹) / tar.gz(tgz) / gz(单文件) / bz2(单文件), 三档 L3/6/9
 *   解压: xz / zip / 7z(含密码) / rar / tar.xz / txz / tgz / tar.gz / gz / bz2 / tar
 *   打开管理: 列出条目、解压选中、删除条目、追加文件、zip 注释查看/写入
 *   校验: 测试压缩包完整性(zip/7z)
 *   系统分享(SEND/SEND_MULTIPLE)直接压缩; SAF 自定义解压目录; 结果输出到 下载/XZFull
 * 说明: 受算法授权限制, 不提供 rar 压缩, 仅支持 rar 解压。
 */
public class MainActivity extends Activity {
    private static final String TAG = "XZFull";
    private static final int REQ_COMPRESS_MULTI = 1001;
    private static final int REQ_COMPRESS_TREE = 1002;
    private static final int REQ_COMPRESS_ONE = 1003;
    private static final int REQ_EXTRACT = 1004;
    private static final int REQ_EXTRACT_TREE = 1005;
    private static final int REQ_OPEN_MGR = 1006;
    private static final int REQ_TEST = 1007;
    private static final int REQ_MGR_ADD = 1008;

    private TextView logView;
    private EditText passInput;
    private Spinner levelSpinner;
    private Uri extractTreeUri;
    // 待压缩格式（压缩菜单选择后设置）
    private String pendingFormat = null;
    private boolean pendingTree = false;
    // 压缩包管理器当前打开的本地文件
    private File mgrFile = null;
    private String mgrType = null;   // zip / 7z

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        buildUi();
        handleSend(getIntent());
        String action = getIntent().getStringExtra("action");
        if (action != null) runBackdoor(action, getIntent().getStringExtra("password"));
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleSend(intent);
        String action = intent.getStringExtra("action");
        if (action != null) runBackdoor(action, intent.getStringExtra("password"));
    }

    private int selectedLevel() {
        int pos = levelSpinner != null ? levelSpinner.getSelectedItemPosition() : 2;
        return new int[]{3, 6, 9}[pos < 0 ? 2 : pos];
    }

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(32, 32, 32, 32);

        TextView title = new TextView(this);
        title.setText("XZ 完整压缩 早期测试版 0.1\n压缩/解压/加密/压缩包管理 · 全格式");
        title.setTextSize(18);
        root.addView(title);

        LinearLayout optRow = new LinearLayout(this);
        optRow.setOrientation(LinearLayout.HORIZONTAL);
        TextView lvLabel = new TextView(this);
        lvLabel.setText("档位: ");
        lvLabel.setTextSize(15);
        levelSpinner = new Spinner(this);
        ArrayAdapter<String> ad = new ArrayAdapter<String>(this,
                android.R.layout.simple_spinner_dropdown_item,
                new String[]{"快速 L3", "标准 L6", "极限 L9"});
        levelSpinner.setAdapter(ad);
        levelSpinner.setSelection(2);
        optRow.addView(lvLabel);
        optRow.addView(levelSpinner);
        root.addView(optRow);

        passInput = new EditText(this);
        passInput.setHint("密码（7z/zip 加密压缩 / 解压加密文件用）");
        root.addView(passInput);

        root.addView(mkBtn("① 压缩文件（xz/7z/zip/tar.xz/gz/bz2）", new View.OnClickListener() {
            public void onClick(View v) { showCompressMenu(); }
        }));
        root.addView(mkBtn("② 解压文件（xz/zip/7z/rar/tar.xz/tgz/gz/bz2）", new View.OnClickListener() {
            public void onClick(View v) { pickOne(REQ_EXTRACT); }
        }));
        root.addView(mkBtn("③ 打开压缩包（列表/解压/删除/追加/注释）", new View.OnClickListener() {
            public void onClick(View v) { pickOne(REQ_OPEN_MGR); }
        }));
        root.addView(mkBtn("④ 测试压缩包完整性（zip/7z）", new View.OnClickListener() {
            public void onClick(View v) { pickOne(REQ_TEST); }
        }));

        final Button btnDir = new Button(this);
        btnDir.setText("⑤ 选择解压目录（默认 下载/XZFull）");
        btnDir.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
                try { startActivityForResult(i, REQ_EXTRACT_TREE); }
                catch (Exception e) { log("打开目录选择器失败: " + e.getMessage()); }
            }
        });
        root.addView(btnDir);

        root.addView(mkBtn("⑥ 解出内置工具库（jar 依赖/许可）", new View.OnClickListener() {
            public void onClick(View v) { extractTools(); }
        }));
        root.addView(mkBtn("⑦ 关于 / 开源许可", new View.OnClickListener() {
            public void onClick(View v) { showAbout(); }
        }));

        logView = new TextView(this);
        logView.setText("就绪。可从系统文件管理器选中文件，用“分享”发送到本应用直接压缩。");
        logView.setTextSize(12);
        ScrollView sv = new ScrollView(this);
        sv.addView(logView);
        root.addView(sv, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));
        setContentView(root);
    }

    private Button mkBtn(String text, View.OnClickListener l) {
        Button b = new Button(this);
        b.setText(text);
        b.setOnClickListener(l);
        return b;
    }

    // ============ 压缩菜单：先选格式，再选单文件/多文件/文件夹 ============
    private void showCompressMenu() {
        final String[] fmts = new String[]{
                ".xz（单文件，极致压缩）",
                ".7z（多文件/文件夹，可加密）",
                ".zip（多文件/文件夹，AES-256 加密）",
                ".tar.xz（多文件/文件夹）",
                ".tar.gz / .tgz（多文件/文件夹）",
                ".gz（单文件 gzip）",
                ".bz2（单文件 bzip2）"
        };
        final String[] codes = new String[]{"xz", "7z", "zip", "tar.xz", "tgz", "gz", "bz2"};
        AlertDialog.Builder b = new AlertDialog.Builder(this);
        b.setTitle("选择压缩格式");
        b.setItems(fmts, new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface d, int which) {
                final String fmt = codes[which];
                pendingFormat = fmt;
                // xz/gz/bz2 为单流单文件；其余可多文件或文件夹
                boolean single = fmt.equals("xz") || fmt.equals("gz") || fmt.equals("bz2");
                if (single) {
                    final String[] src = new String[]{"选择一个文件"};
                    new AlertDialog.Builder(MainActivity.this)
                            .setTitle(fmt + " 压缩").setItems(src, new DialogInterface.OnClickListener() {
                        public void onClick(DialogInterface dd, int ww) { pickOne(REQ_COMPRESS_ONE); }
                    }).show();
                } else {
                    final String[] src = new String[]{"选择多个文件", "选择整个文件夹"};
                    new AlertDialog.Builder(MainActivity.this)
                            .setTitle(fmt + " 压缩").setItems(src, new DialogInterface.OnClickListener() {
                        public void onClick(DialogInterface dd, int ww) {
                            if (ww == 0) {
                                pendingTree = false;
                                pickMulti(REQ_COMPRESS_MULTI);
                            } else {
                                pendingTree = true;
                                pickTree(REQ_COMPRESS_TREE);
                            }
                        }
                    }).show();
                }
            }
        });
        b.show();
    }

    private void pickOne(int code) {
        Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType("*/*");
        try { startActivityForResult(i, code); }
        catch (Exception e) { log("打开文件选择器失败: " + e.getMessage()); }
    }

    private void pickMulti(int code) {
        Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType("*/*");
        i.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
        try { startActivityForResult(i, code); }
        catch (Exception e) { log("打开选择器失败: " + e.getMessage()); }
    }

    private void pickTree(int code) {
        Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        try { startActivityForResult(i, code); }
        catch (Exception e) { log("打开文件夹选择器失败: " + e.getMessage()); }
    }

    private void handleSend(Intent intent) {
        if (intent == null) return;
        String act = intent.getAction();
        final ArrayList<Uri> uris = new ArrayList<Uri>();
        if (Intent.ACTION_SEND.equals(act)) {
            Uri u = intent.getParcelableExtra(Intent.EXTRA_STREAM);
            if (u != null) uris.add(u);
        } else if (Intent.ACTION_SEND_MULTIPLE.equals(act)) {
            ArrayList<Uri> list = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM);
            if (list != null) uris.addAll(list);
            Uri single = intent.getParcelableExtra(Intent.EXTRA_STREAM);
            if (uris.isEmpty() && single != null) uris.add(single);
        }
        if (uris.isEmpty()) return;
        log("分享接收: " + uris.size() + " 个文件, 开始压缩为 7z");
        Toast.makeText(this, "收到 " + uris.size() + " 个文件，开始压缩为 7z", Toast.LENGTH_LONG).show();
        final String pw = passInput != null ? passInput.getText().toString() : "";
        final int lv = selectedLevel();
        new Thread(new Runnable() {
            public void run() {
                try {
                    String name = "shared_" + System.currentTimeMillis() + "_L" + lv + ".7z";
                    doCompress7z(uris, null, name, pw, lv);
                } catch (final Exception e) {
                    log("分享压缩错误: " + e);
                }
            }
        }).start();
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (resultCode != RESULT_OK || data == null) return;
        final String pw = passInput.getText().toString();
        final int lv = selectedLevel();

        if (requestCode == REQ_EXTRACT_TREE) {
            extractTreeUri = data.getData();
            final int takeFlags = data.getFlags() & (Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
            try { getContentResolver().takePersistableUriPermission(extractTreeUri, takeFlags); } catch (Exception ignored) {}
            log("解压目录已设置（SAF）: " + extractTreeUri);
            return;
        }

        if (requestCode == REQ_COMPRESS_TREE) {
            final Uri tree = data.getData();
            final String fmt = pendingFormat;
            new Thread(new Runnable() {
                public void run() {
                    try {
                        String root = queryTreeName(tree);
                        String base = (root != null ? root : "folder");
                        dispatchCompressTree(fmt, tree, base, pw, lv);
                    } catch (Exception e) { log("错误: " + e); }
                }
            }).start();
            return;
        }

        if (requestCode == REQ_COMPRESS_MULTI) {
            final ArrayList<Uri> uris = collectUris(data);
            if (uris.isEmpty()) { log("未选择文件"); return; }
            final String fmt = pendingFormat;
            new Thread(new Runnable() {
                public void run() {
                    try {
                        String base = (uris.size() == 1 ? stripExt(queryName(uris.get(0))) : "archive");
                        dispatchCompressMulti(fmt, uris, base, pw, lv);
                    } catch (Exception e) { log("错误: " + e); }
                }
            }).start();
            return;
        }

        final Uri uri = data.getData();
        if (uri == null) return;
        if (requestCode == REQ_COMPRESS_ONE) {
            final String fmt = pendingFormat;
            new Thread(new Runnable() {
                public void run() {
                    try { dispatchCompressOne(fmt, uri, pw, lv); }
                    catch (Exception e) { log("错误: " + e); }
                }
            }).start();
            return;
        }
        if (requestCode == REQ_EXTRACT) {
            new Thread(new Runnable() {
                public void run() {
                    try { doExtract(uri, null, pw); }
                    catch (Exception e) { log("错误: " + e); }
                }
            }).start();
            return;
        }
        if (requestCode == REQ_TEST) {
            new Thread(new Runnable() {
                public void run() {
                    try { doTest(uri); }
                    catch (Exception e) { log("错误: " + e); }
                }
            }).start();
            return;
        }
        if (requestCode == REQ_OPEN_MGR) {
            new Thread(new Runnable() {
                public void run() {
                    try { openManager(uri); }
                    catch (Exception e) { log("错误: " + e); }
                }
            }).start();
            return;
        }
        if (requestCode == REQ_MGR_ADD) {
            final ArrayList<Uri> addUris = collectUris(data);
            if (addUris.isEmpty()) { log("未选择要追加的文件"); return; }
            new Thread(new Runnable() {
                public void run() {
                    try { mgrAddFiles(addUris, pw, lv); }
                    catch (Exception e) { log("追加错误: " + e); }
                }
            }).start();
            return;
        }
    }

    private ArrayList<Uri> collectUris(Intent data) {
        ArrayList<Uri> out = new ArrayList<Uri>();
        ClipData clip = data.getClipData();
        if (clip != null) {
            for (int i = 0; i < clip.getItemCount(); i++) {
                Uri u = clip.getItemAt(i).getUri();
                if (u != null) out.add(u);
            }
        } else if (data.getData() != null) {
            out.add(data.getData());
        }
        return out;
    }

    // ============ 压缩分发 ============
    private void dispatchCompressOne(String fmt, Uri uri, String pw, int lv) throws Exception {
        String name = queryName(uri);
        if ("xz".equals(fmt)) doCompressXz(uri, null);
        else if ("gz".equals(fmt)) doCompressSingleStream(uri, name, "gz", lv);
        else if ("bz2".equals(fmt)) doCompressSingleStream(uri, name, "bz2", lv);
    }

    private void dispatchCompressMulti(String fmt, ArrayList<Uri> uris, String base, String pw, int lv) throws Exception {
        if ("7z".equals(fmt)) {
            doCompress7z(uris, null, base + "_L" + lv + ".7z", pw, lv);
        } else if ("zip".equals(fmt)) {
            doCompressZip(uris, null, base + "_L" + lv + ".zip", pw, lv);
        } else if ("tar.xz".equals(fmt)) {
            doCompressTar(uris, null, base + ".tar.xz", "xz", lv);
        } else if ("tgz".equals(fmt)) {
            doCompressTar(uris, null, base + ".tar.gz", "gz", lv);
        }
    }

    private void dispatchCompressTree(String fmt, Uri tree, String base, String pw, int lv) throws Exception {
        if ("7z".equals(fmt)) {
            doCompress7z(null, tree, base + "_L" + lv + ".7z", pw, lv);
        } else if ("zip".equals(fmt)) {
            doCompressZip(null, tree, base + "_L" + lv + ".zip", pw, lv);
        } else if ("tar.xz".equals(fmt)) {
            doCompressTar(null, tree, base + ".tar.xz", "xz", lv);
        } else if ("tgz".equals(fmt)) {
            doCompressTar(null, tree, base + ".tar.gz", "gz", lv);
        }
    }

    // ============ 自动化测试后门 ============
    private void runBackdoor(String action, String password) {
        new Thread(new Runnable() {
            public void run() {
                try {
                    File dir = getExternalFilesDir(null);
                    if (dir == null) { log("外部目录不可用"); return; }
                    final String pw = password != null ? password : "";
                    if (action.equals("compress")) {
                        File[] files = dir.listFiles();
                        if (files == null) { log("目录为空"); return; }
                        for (File f : files) {
                            if (f.isFile() && !f.getName().endsWith(".xz"))
                                doCompressXz(Uri.fromFile(f), f.getName());
                        }
                        log("xz 测试压缩完成");
                    } else if (action.equals("zipcompress")) {
                        ArrayList<Uri> uris = new ArrayList<Uri>();
                        File[] files = dir.listFiles();
                        if (files == null) { log("目录为空"); return; }
                        for (File f : files) {
                            if (f.isFile() && !f.getName().endsWith(".zip")) uris.add(Uri.fromFile(f));
                        }
                        if (!uris.isEmpty()) doCompressZip(uris, null, "selftest.zip", pw, 9);
                        log("zip 测试压缩完成");
                    } else if (action.equals("7zcompress")) {
                        ArrayList<Uri> uris = new ArrayList<Uri>();
                        File[] files = dir.listFiles();
                        if (files == null) { log("目录为空"); return; }
                        for (File f : files) {
                            if (f.isFile() && !f.getName().endsWith(".7z")) uris.add(Uri.fromFile(f));
                        }
                        if (!uris.isEmpty()) doCompress7z(uris, null, "selftest_7z_L9.7z", pw, 9);
                        log("7z 测试压缩完成");
                    } else if (action.equals("extract")) {
                        File[] files = dir.listFiles();
                        if (files == null) { log("目录为空"); return; }
                        for (File f : files) {
                            if (f.isFile() && isArchive(f.getName()))
                                doExtract(Uri.fromFile(f), f.getName(), pw);
                        }
                        log("测试解压完成");
                    } else if (action.equals("extracttools")) {
                        extractTools();
                    }
                } catch (final Exception e) {
                    log("后门错误: " + e);
                }
            }
        }).start();
    }

    private boolean isArchive(String name) {
        String n = name.toLowerCase();
        return n.endsWith(".xz") || n.endsWith(".zip") || n.endsWith(".7z") || n.endsWith(".rar")
                || n.endsWith(".gz") || n.endsWith(".tgz") || n.endsWith(".bz2") || n.endsWith(".tar");
    }

    private String stripExt(String name) {
        int i = name.lastIndexOf('.');
        return i > 0 ? name.substring(0, i) : name;
    }

    // ============ xz 单文件压缩 ============
    private void doCompressXz(Uri uri, String forcedName) throws Exception {
        String name = forcedName != null ? forcedName : queryName(uri);
        log("xz 压缩: " + name);
        InputStream in = getContentResolver().openInputStream(uri);
        if (in == null) { log("无法读取: " + name); return; }
        String outName = name + ".xz";
        Uri outUri = createOutput(outName);
        OutputStream out = getContentResolver().openOutputStream(outUri);
        int lv = selectedLevel();
        LZMA2Options opts = new LZMA2Options(lv >= 9 ? LZMA2Options.PRESET_MAX : lv);
        if (lv >= 9) opts.setDictSize(1 << 24);
        XZOutputStream xz = new XZOutputStream(out, opts);
        byte[] buf = new byte[65536];
        long total = 0;
        int n;
        while ((n = in.read(buf)) > 0) { xz.write(buf, 0, n); total += n; }
        xz.finish();
        xz.close();
        in.close();
        log("完成: " + name + " -> " + outName + "  (" + total + " 字节, L" + lv + ")");
    }

    // ============ gz / bz2 单文件压缩 ============
    private void doCompressSingleStream(Uri uri, String name, String kind, int lv) throws Exception {
        log(kind + " 压缩: " + name);
        File tmp = new File(getCacheDir(), "ss_" + UUID.randomUUID().toString());
        copyUriToFile(uri, tmp);
        String outName = name + "." + kind;
        File outTmp = new File(getCacheDir(), safeName(outName));
        if (outTmp.exists()) outTmp.delete();
        InputStream fin = new BufferedInputStream(new FileInputStream(tmp));
        OutputStream fout = new FileOutputStream(outTmp);
        OutputStream cout = kind.equals("gz")
                ? new GzipCompressorOutputStream(fout)
                : new BZip2CompressorOutputStream(fout);
        byte[] buf = new byte[65536];
        int n;
        long total = 0;
        while ((n = fin.read(buf)) > 0) { cout.write(buf, 0, n); total += n; }
        cout.close();
        fin.close();
        publishFile(outTmp, outName);
        tmp.delete();
        log("完成: -> " + outName + "  (" + total + " 字节)");
    }

    // ============ zip 多文件/文件夹（AES-256） ============
    private void doCompressZip(List<Uri> uris, Uri treeUri, String outName,
                               String password, int level) throws Exception {
        boolean enc = password != null && password.length() > 0;
        log("zip 压缩: " + outName + (enc ? " (AES-256 加密)" : ""));
        File work = new File(getCacheDir(), "zipwork_" + UUID.randomUUID().toString());
        File outZip = new File(getCacheDir(), safeName(outName));
        work.mkdirs();
        if (outZip.exists()) outZip.delete();
        try {
            if (treeUri != null) {
                String rootName = queryTreeName(treeUri);
                File root = new File(work, rootName != null ? safeName(rootName) : "folder");
                root.mkdirs();
                String rootId = DocumentsContract.getTreeDocumentId(treeUri);
                Uri rootDoc = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootId);
                copyTreeIn(rootDoc, treeUri, root);
            } else {
                for (Uri u : uris) {
                    String nm = uniqueName(work, safeName(queryName(u)));
                    copyUriToFile(u, new File(work, nm));
                }
            }
            ZipFile zf = new ZipFile(outZip);
            if (enc) zf.setPassword(password.toCharArray());
            ZipParameters zp = new ZipParameters();
            zp.setCompressionMethod(CompressionMethod.DEFLATE);
            CompressionLevel[] cls = new CompressionLevel[]{
                    CompressionLevel.NORMAL, CompressionLevel.HIGHER, CompressionLevel.ULTRA};
            zp.setCompressionLevel(cls[level == 3 ? 0 : level == 6 ? 1 : 2]);
            if (enc) {
                zp.setEncryptFiles(true);
                zp.setEncryptionMethod(EncryptionMethod.AES);
                zp.setAesKeyStrength(AesKeyStrength.KEY_STRENGTH_256);
            }
            File[] tops = work.listFiles();
            if (tops != null) {
                for (File t : tops) {
                    if (t.isDirectory()) zf.addFolder(t, zp);
                    else zf.addFile(t, zp);
                }
            }
            zf.close();
            long zipLen = outZip.length();
            publishFile(outZip, outName);
            log("完成: -> " + outName + "  大小 " + zipLen + " 字节");
        } finally {
            deleteRecursive(work);
            try { outZip.delete(); } catch (Exception ignored) {}
        }
    }

    // ============ tar.xz / tar.gz 多文件/文件夹 ============
    private void doCompressTar(List<Uri> uris, Uri treeUri, String outName,
                               String streamKind, int level) throws Exception {
        log("tar" + ("xz".equals(streamKind) ? ".xz" : ".gz") + " 压缩: " + outName);
        File work = new File(getCacheDir(), "tarwork_" + UUID.randomUUID().toString());
        File outFinal = new File(getCacheDir(), safeName(outName));
        work.mkdirs();
        if (outFinal.exists()) outFinal.delete();
        try {
            if (treeUri != null) {
                String rootName = queryTreeName(treeUri);
                File root = new File(work, rootName != null ? safeName(rootName) : "folder");
                root.mkdirs();
                String rootId = DocumentsContract.getTreeDocumentId(treeUri);
                Uri rootDoc = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootId);
                copyTreeIn(rootDoc, treeUri, root);
            } else {
                for (Uri u : uris) {
                    String nm = uniqueName(work, safeName(queryName(u)));
                    copyUriToFile(u, new File(work, nm));
                }
            }
            File tarFile = new File(getCacheDir(), "tar_" + UUID.randomUUID().toString() + ".tar");
            OutputStream tout = new BufferedOutputStream(new FileOutputStream(tarFile));
            TarArchiveOutputStream tos = new TarArchiveOutputStream(tout);
            tos.setLongFileMode(TarArchiveOutputStream.LONGFILE_POSIX);
            File[] tops = work.listFiles();
            if (tops != null) {
                for (File t : tops) addToTar(tos, t, "");
            }
            tos.finish();
            tos.close();

            OutputStream fout = new FileOutputStream(outFinal);
            InputStream tin = new BufferedInputStream(new FileInputStream(tarFile));
            OutputStream wrap;
            if ("xz".equals(streamKind)) {
                LZMA2Options opts = new LZMA2Options(level >= 9 ? LZMA2Options.PRESET_MAX : level);
                if (level >= 9) opts.setDictSize(1 << 24);
                wrap = new XZOutputStream(fout, opts);
            } else {
                wrap = new GzipCompressorOutputStream(fout);
            }
            byte[] buf = new byte[65536];
            int n;
            while ((n = tin.read(buf)) > 0) wrap.write(buf, 0, n);
            wrap.close();
            tin.close();
            tarFile.delete();
            long tarLen = outFinal.length();
            publishFile(outFinal, outName);
            log("完成: -> " + outName + "  大小 " + tarLen + " 字节");
        } finally {
            deleteRecursive(work);
            try { outFinal.delete(); } catch (Exception ignored) {}
        }
    }

    private void addToTar(TarArchiveOutputStream tos, File f, String base) throws IOException {
        String entryName = base + f.getName();
        if (f.isDirectory()) entryName = entryName + "/";
        TarArchiveEntry e = new TarArchiveEntry(f, entryName);
        tos.putArchiveEntry(e);
        if (f.isFile()) {
            InputStream in = new FileInputStream(f);
            byte[] buf = new byte[65536];
            int n;
            while ((n = in.read(buf)) > 0) tos.write(buf, 0, n);
            in.close();
        }
        tos.closeArchiveEntry();
        if (f.isDirectory()) {
            File[] kids = f.listFiles();
            if (kids != null) for (File k : kids) addToTar(tos, k, entryName);
        }
    }

    // ============ 7z 压缩（多文件/文件夹, 可加密） ============
    private void doCompress7z(List<Uri> uris, Uri treeUri, String outName,
                              String password, int level) throws Exception {
        boolean enc = password != null && password.length() > 0;
        log("7z 压缩: " + outName + "  L" + level + (enc ? "  (加密)" : ""));
        File work = new File(getCacheDir(), "7zwork_" + UUID.randomUUID().toString());
        String outFile = safeName(outName);
        File out7z = new File(getCacheDir(), outFile);
        work.mkdirs();
        if (out7z.exists()) out7z.delete();
        try {
            if (treeUri != null) {
                String rootName = queryTreeName(treeUri);
                File root = new File(work, rootName != null ? safeName(rootName) : "folder");
                root.mkdirs();
                String rootId = DocumentsContract.getTreeDocumentId(treeUri);
                Uri rootDoc = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootId);
                copyTreeIn(rootDoc, treeUri, root);
            } else {
                for (Uri u : uris) {
                    String nm = uniqueName(work, safeName(queryName(u)));
                    copyUriToFile(u, new File(work, nm));
                }
            }

            SevenZOutputFile sz = enc
                    ? new SevenZOutputFile(out7z, password.toCharArray())
                    : new SevenZOutputFile(out7z);
            LZMA2Options lo = new LZMA2Options(level >= 9 ? LZMA2Options.PRESET_MAX : level);
            if (level >= 9) lo.setDictSize(1 << 24);
            sz.setContentMethods(Collections.singletonList(
                    new SevenZMethodConfiguration(SevenZMethod.LZMA2, lo)));
            File[] tops = work.listFiles();
            if (tops != null) {
                for (File t : tops) addTo7z(sz, t, "");
            }
            sz.close();
            long sz7 = out7z.length();
            publishFile(out7z, outFile);
            log("完成: -> " + outFile + "  大小 " + sz7 + " 字节");
        } finally {
            deleteRecursive(work);
            try { out7z.delete(); } catch (Exception ignored) {}
        }
    }

    private void addTo7z(SevenZOutputFile sz, File f, String base) throws IOException {
        String entryName = base + f.getName();
        if (f.isDirectory()) entryName = entryName + "/";
        SevenZArchiveEntry e = sz.createArchiveEntry(f, entryName);
        sz.putArchiveEntry(e);
        if (f.isFile()) {
            InputStream in = new FileInputStream(f);
            byte[] buf = new byte[65536];
            int n;
            while ((n = in.read(buf)) > 0) { sz.write(buf, 0, n); }
            in.close();
        }
        sz.closeArchiveEntry();
        if (f.isDirectory()) {
            File[] kids = f.listFiles();
            if (kids != null) for (File k : kids) addTo7z(sz, k, entryName);
        }
    }

    private void copyTreeIn(Uri docUri, Uri treeUri, File dst) throws Exception {
        ContentResolver cr = getContentResolver();
        String docId = DocumentsContract.getDocumentId(docUri);
        Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, docId);
        Cursor c = cr.query(children, new String[]{
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE}, null, null, null);
        if (c == null) return;
        try {
            while (c.moveToNext()) {
                String cid = c.getString(0);
                String cname = c.getString(1);
                String cmime = c.getString(2);
                Uri childDoc = DocumentsContract.buildDocumentUriUsingTree(treeUri, cid);
                File child = new File(dst, cname != null ? safeName(cname) : ("item_" + cid.hashCode()));
                if (DocumentsContract.Document.MIME_TYPE_DIR.equals(cmime)) {
                    child.mkdirs();
                    copyTreeIn(childDoc, treeUri, child);
                } else {
                    InputStream in = cr.openInputStream(childDoc);
                    if (in != null) {
                        FileOutputStream fos = new FileOutputStream(child);
                        byte[] buf = new byte[65536];
                        int n;
                        while ((n = in.read(buf)) > 0) fos.write(buf, 0, n);
                        fos.close();
                        in.close();
                    }
                }
            }
        } finally {
            c.close();
        }
    }

    // ============ 解压总入口（支持全格式） ============
    private void doExtract(Uri uri, String forcedName, String password) throws Exception {
        String name = forcedName != null ? forcedName : queryName(uri);
        log("解压: " + name);
        String lower = name.toLowerCase();
        File tmp = new File(getCacheDir(), "ext_" + UUID.randomUUID().toString());
        tmp.getParentFile().mkdirs();
        try {
            copyUriToFile(uri, tmp);
            File result;
            boolean isDir = false;
            String resultName;
            if (lower.endsWith(".tar.xz") || lower.endsWith(".txz")) {
                File r = extractTarStream(tmp, name, "xz");
                result = r; isDir = true; resultName = stripDouble(name, ".tar.xz", ".txz") + "/";
            } else if (lower.endsWith(".tar.gz") || lower.endsWith(".tgz")) {
                File r = extractTarStream(tmp, name, "gz");
                result = r; isDir = true; resultName = stripDouble(name, ".tar.gz", ".tgz") + "/";
            } else if (lower.endsWith(".xz")) {
                File r = extractXz(tmp, name);
                result = r; isDir = false; resultName = r.getName();
            } else if (lower.endsWith(".gz")) {
                File r = extractSingleStream(tmp, name, "gz");
                result = r; isDir = false; resultName = r.getName();
            } else if (lower.endsWith(".bz2")) {
                File r = extractSingleStream(tmp, name, "bz2");
                result = r; isDir = false; resultName = r.getName();
            } else if (lower.endsWith(".tar")) {
                File r = extractTarPlain(tmp, name);
                result = r; isDir = true; resultName = stripExt(name) + "/";
            } else if (lower.endsWith(".zip")) {
                File r = extractZip(tmp, name, password);
                result = r; isDir = true; resultName = stripExt(name) + "/";
            } else if (lower.endsWith(".7z")) {
                File r = extract7z(tmp, name, password);
                result = r; isDir = true; resultName = stripExt(name) + "/";
            } else if (lower.endsWith(".rar")) {
                File r = extractRar(tmp, name);
                result = r; isDir = true; resultName = stripExt(name) + "/";
            } else {
                log("不支持的类型: " + name);
                return;
            }
            deliver(result, isDir, resultName);
        } finally {
            tmp.delete();
        }
    }

    private String stripDouble(String name, String a, String b) {
        String n = name.toLowerCase();
        if (n.endsWith(a)) return name.substring(0, name.length() - a.length());
        if (n.endsWith(b)) return name.substring(0, name.length() - b.length());
        return stripExt(name);
    }

    private File extractXz(File tmp, String name) throws Exception {
        String outName = name.toLowerCase().endsWith(".xz")
                ? name.substring(0, name.length() - 3) : name + ".out";
        File outTmp = new File(getCacheDir(), safeName(outName));
        XZInputStream xz = new XZInputStream(new FileInputStream(tmp));
        FileOutputStream fos = new FileOutputStream(outTmp);
        pump(xz, fos);
        log("完成: 解压为 " + outName);
        return outTmp;
    }

    private File extractSingleStream(File tmp, String name, String kind) throws Exception {
        String outName = name.toLowerCase().endsWith("." + kind)
                ? name.substring(0, name.length() - kind.length() - 1) : name + ".out";
        File outTmp = new File(getCacheDir(), safeName(outName));
        InputStream in = kind.equals("gz")
                ? new GzipCompressorInputStream(new BufferedInputStream(new FileInputStream(tmp)))
                : new BZip2CompressorInputStream(new BufferedInputStream(new FileInputStream(tmp)));
        FileOutputStream fos = new FileOutputStream(outTmp);
        pump(in, fos);
        log("完成: 解压为 " + outName);
        return outTmp;
    }

    private File extractTarStream(File tmp, String name, String kind) throws Exception {
        File tarFile = new File(getCacheDir(), "t_" + UUID.randomUUID().toString() + ".tar");
        InputStream in = kind.equals("xz")
                ? new XZInputStream(new FileInputStream(tmp))
                : new GzipCompressorInputStream(new BufferedInputStream(new FileInputStream(tmp)));
        FileOutputStream tos = new FileOutputStream(tarFile);
        pump(in, tos);
        return extractTarPlain(tarFile, name);
    }

    private File extractTarPlain(File tarFile, String name) throws Exception {
        String outName = stripDouble(name, ".tar.xz", ".txz");
        if (outName.equals(name)) outName = name.toLowerCase().endsWith(".tar.gz")
                ? name.substring(0, name.length() - 7) : stripExt(name);
        File outTmp = new File(getCacheDir(), safeName(outName) + "_dir");
        outTmp.mkdirs();
        TarArchiveInputStream tis = new TarArchiveInputStream(new BufferedInputStream(new FileInputStream(tarFile)));
        TarArchiveEntry te;
        byte[] buf = new byte[65536];
        while ((te = tis.getNextTarEntry()) != null) {
            File f = new File(outTmp, te.getName().replace('\\', '/'));
            File parent = f.getParentFile();
            if (parent != null) parent.mkdirs();
            if (te.isDirectory()) { f.mkdirs(); continue; }
            FileOutputStream fos = new FileOutputStream(f);
            int r;
            while ((r = tis.read(buf)) > 0) fos.write(buf, 0, r);
            fos.close();
        }
        tis.close();
        tarFile.delete();
        log("完成: tar 解压为 " + outTmp.getName());
        return outTmp;
    }

    private File extractZip(File tmp, String name, String password) throws Exception {
        String outName = name.toLowerCase().endsWith(".zip")
                ? name.substring(0, name.length() - 4) : name + ".out";
        File outTmp = new File(getCacheDir(), outName + "_dir");
        outTmp.mkdirs();
        ZipFile zf = new ZipFile(tmp);
        if (password != null && password.length() > 0) zf.setPassword(password.toCharArray());
        zf.extractAll(outTmp.getAbsolutePath());
        zf.close();
        log("完成: zip 解压为 " + outName + "/");
        return outTmp;
    }

    private File extract7z(File tmp, String name, String password) throws Exception {
        String outName = name.toLowerCase().endsWith(".7z")
                ? name.substring(0, name.length() - 3) : name + ".out";
        File outTmp = new File(getCacheDir(), outName + "_dir");
        outTmp.mkdirs();
        SevenZFile sevenZFile = (password != null && password.length() > 0)
                ? new SevenZFile(tmp, password.toCharArray())
                : new SevenZFile(tmp);
        SevenZArchiveEntry entry;
        byte[] buf = new byte[65536];
        while ((entry = sevenZFile.getNextEntry()) != null) {
            if (entry.isDirectory()) continue;
            String fn = entry.getName();
            if (fn == null || fn.length() == 0) fn = "file_" + System.nanoTime();
            fn = fn.replace('\\', '/');
            File f = new File(outTmp, fn);
            File parent = f.getParentFile();
            if (parent != null) parent.mkdirs();
            FileOutputStream fos = new FileOutputStream(f);
            int r;
            while ((r = sevenZFile.read(buf)) > 0) { fos.write(buf, 0, r); }
            fos.close();
        }
        sevenZFile.close();
        log("完成: 7z 解压为 " + outName + "/");
        return outTmp;
    }

    private File extractRar(File tmp, String name) throws Exception {
        String outName = name.toLowerCase().endsWith(".rar")
                ? name.substring(0, name.length() - 4) : name + ".out";
        File outTmp = new File(getCacheDir(), outName + "_dir");
        outTmp.mkdirs();
        Archive archive = new Archive(tmp);
        com.github.junrar.rarfile.FileHeader fh;
        byte[] buf = new byte[65536];
        while ((fh = archive.nextFileHeader()) != null) {
            if (fh.isDirectory()) continue;
            String fn = fh.getFileNameString();
            if (fn == null || fn.length() == 0) fn = "file_" + System.nanoTime();
            fn = fn.replace('\\', '/');
            File f = new File(outTmp, fn);
            File parent = f.getParentFile();
            if (parent != null) parent.mkdirs();
            FileOutputStream fos = new FileOutputStream(f);
            InputStream is = archive.getInputStream(fh);
            int r;
            while ((r = is.read(buf)) > 0) { fos.write(buf, 0, r); }
            is.close();
            fos.close();
        }
        archive.close();
        log("完成: rar 解压为 " + outName + "/");
        return outTmp;
    }

    private void pump(InputStream in, OutputStream out) throws Exception {
        byte[] buf = new byte[65536];
        int n;
        long total = 0;
        while ((n = in.read(buf)) > 0) { out.write(buf, 0, n); total += n; }
        in.close();
        out.close();
    }

    // ============ 压缩包完整性测试 ============
    private void doTest(Uri uri) throws Exception {
        String name = queryName(uri);
        String lower = name.toLowerCase();
        File tmp = new File(getCacheDir(), "tst_" + UUID.randomUUID().toString());
        copyUriToFile(uri, tmp);
        try {
            if (lower.endsWith(".zip")) {
                ZipFile zf = new ZipFile(tmp);
                if (passInput.getText().length() > 0) zf.setPassword(passInput.getText().toString().toCharArray());
                boolean ok = zf.isValidZipFile();
                if (ok) {
                    int c = 0;
                    List<FileHeader> hs = zf.getFileHeaders();
                    for (FileHeader h : hs) {
                        if (h.isDirectory()) continue;
                        try { zf.extractFile(h, getCacheDir().getAbsolutePath() + "/ztest_" + UUID.randomUUID()); }
                        catch (Exception e) { ok = false; log("损坏条目: " + h.getFileName() + " -> " + e.getMessage()); break; }
                        c++;
                    }
                    log("测试结果: " + (ok ? "通过" : "失败") + "（zip，校验 " + c + " 个文件）");
                } else {
                    log("测试结果: 失败（zip 结构无效，可能损坏或密码错误）");
                }
                zf.close();
            } else if (lower.endsWith(".7z")) {
                SevenZFile sf;
                try {
                    sf = passInput.getText().length() > 0
                            ? new SevenZFile(tmp, passInput.getText().toString().toCharArray())
                            : new SevenZFile(tmp);
                } catch (Exception e) {
                    log("测试结果: 无法打开（可能损坏或密码错误）: " + e.getMessage());
                    return;
                }
                SevenZArchiveEntry en;
                long total = 0;
                byte[] buf = new byte[65536];
                boolean ok = true;
                try {
                    while ((en = sf.getNextEntry()) != null) {
                        if (en.isDirectory()) continue;
                        int r;
                        while ((r = sf.read(buf)) > 0) total += r;
                    }
                } catch (Exception e) {
                    ok = false;
                    log("读取损坏: " + e.getMessage());
                }
                sf.close();
                log("测试结果: " + (ok ? "通过" : "失败") + "（7z，读取 " + total + " 字节）");
            } else {
                log("测试仅支持 .zip / .7z；其余格式请用“解压”验证。");
            }
        } finally {
            tmp.delete();
        }
    }

    // ============ 压缩包管理器 ============
    private void openManager(Uri uri) throws Exception {
        final String name = queryName(uri);
        String lower = name.toLowerCase();
        if (!lower.endsWith(".zip") && !lower.endsWith(".7z")) {
            log("压缩包管理仅支持 .zip / .7z（其余格式请用“解压”）");
            return;
        }
        File tmp = new File(getCacheDir(), "mgr_" + UUID.randomUUID().toString());
        copyUriToFile(uri, tmp);
        mgrFile = tmp;
        mgrType = lower.endsWith(".zip") ? "zip" : "7z";
        mgrList();
    }

    private void mgrList() {
        try {
            final ArrayList<String> items = new ArrayList<String>();
            if ("zip".equals(mgrType)) {
                ZipFile zf = new ZipFile(mgrFile);
                if (passInput.getText().length() > 0) zf.setPassword(passInput.getText().toString().toCharArray());
                List<FileHeader> hs = zf.getFileHeaders();
                for (FileHeader h : hs)
                    items.add((h.isDirectory() ? "[目录] " : "[文件] ") + h.getFileName()
                            + (h.isEncrypted() ? "  🔒" : ""));
                String comment = zf.getComment();
                if (comment != null && comment.length() > 0) items.add(0, "📝 注释: " + comment);
                zf.close();
            } else {
                SevenZFile sf = passInput.getText().length() > 0
                        ? new SevenZFile(mgrFile, passInput.getText().toString().toCharArray())
                        : new SevenZFile(mgrFile);
                SevenZArchiveEntry e;
                while ((e = sf.getNextEntry()) != null)
                    items.add((e.isDirectory() ? "[目录] " : "[文件] ") + e.getName());
                sf.close();
            }
            items.add("──── 操作 ────");
            runOnUiThread(new Runnable() {
                public void run() {
                    AlertDialog.Builder b = new AlertDialog.Builder(MainActivity.this);
                    b.setTitle("压缩包内容（" + mgrType + "，共 " + Math.max(0, items.size() - 1) + " 项）");
                    String[] ops = new String[]{
                            "全部解压",
                            "追加文件到此压缩包",
                            "删除条目…",
                            "设置/修改 zip 注释",
                            "保存并关闭"
                    };
                    b.setItems(items.toArray(new String[0]), null);
                    b.setPositiveButton("关闭", null);
                    b.setNeutralButton("操作", new DialogInterface.OnClickListener() {
                        public void onClick(DialogInterface d, int w) { showMgrOps(); }
                    });
                    b.show();
                }
            });
        } catch (final Exception e) {
            log("打开压缩包失败（可能需要密码）: " + e.getMessage());
        }
    }

    private void showMgrOps() {
        final String[] ops = new String[]{"全部解压", "追加文件", "删除条目…", "设置/修改 zip 注释", "保存并关闭"};
        new AlertDialog.Builder(this).setTitle("压缩包操作").setItems(ops, new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface d, int which) {
                if (which == 0) {
                    new Thread(new Runnable() { public void run() {
                        try { mgrExtractAll(); } catch (Exception e) { log("解压错误: " + e); }
                    }}).start();
                } else if (which == 1) {
                    Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                    i.addCategory(Intent.CATEGORY_OPENABLE);
                    i.setType("*/*");
                    i.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
                    try { startActivityForResult(i, REQ_MGR_ADD); } catch (Exception e) { log("选择失败: " + e.getMessage()); }
                } else if (which == 2) {
                    mgrDeletePrompt();
                } else if (which == 3) {
                    mgrCommentPrompt();
                } else if (which == 4) {
                    mgrSaveAndClose();
                }
            }
        }).show();
    }

    private void mgrExtractAll() throws Exception {
        String pw = passInput.getText().toString();
        File outDir;
        if ("zip".equals(mgrType)) {
            outDir = extractZip(mgrFile, "mgr.zip", pw);
        } else {
            outDir = extract7z(mgrFile, "mgr.7z", pw);
        }
        deliver(outDir, true, "mgr/");
        log("已解压压缩包内全部内容。");
    }

    private void mgrAddFiles(ArrayList<Uri> uris, String pw, int lv) throws Exception {
        File work = new File(getCacheDir(), "mgradd_" + UUID.randomUUID().toString());
        work.mkdirs();
        try {
            for (Uri u : uris) {
                String nm = uniqueName(work, safeName(queryName(u)));
                copyUriToFile(u, new File(work, nm));
            }
            if ("zip".equals(mgrType)) {
                ZipFile zf = new ZipFile(mgrFile);
                if (pw != null && pw.length() > 0) zf.setPassword(pw.toCharArray());
                ZipParameters zp = new ZipParameters();
                zp.setCompressionMethod(CompressionMethod.DEFLATE);
                CompressionLevel[] cls = new CompressionLevel[]{
                        CompressionLevel.NORMAL, CompressionLevel.HIGHER, CompressionLevel.ULTRA};
                zp.setCompressionLevel(cls[lv == 3 ? 0 : lv == 6 ? 1 : 2]);
                File[] fs = work.listFiles();
                if (fs != null) for (File f : fs) zf.addFile(f, zp);
                zf.close();
                log("已追加 " + (fs == null ? 0 : fs.length) + " 个文件到 zip。");
            } else {
                rebuild7zAdd(work, pw, lv);
                log("已追加文件到 7z（重打包）。");
            }
            mgrList();
        } finally {
            deleteRecursive(work);
        }
    }

    // 7z 追加：读出全部条目，连同新文件重写为新 7z
    private void rebuild7zAdd(File addDir, String pw, int lv) throws Exception {
        File old = mgrFile;
        File nw = new File(getCacheDir(), "mgr7z_" + UUID.randomUUID().toString() + ".7z");
        File exdir = new File(getCacheDir(), "mgr7ex_" + UUID.randomUUID().toString());
        exdir.mkdirs();
        try {
            // 1) 解压原内容
            SevenZFile rd = (pw != null && pw.length() > 0)
                    ? new SevenZFile(old, pw.toCharArray()) : new SevenZFile(old);
            SevenZArchiveEntry en;
            byte[] buf = new byte[65536];
            while ((en = rd.getNextEntry()) != null) {
                String fn = en.getName().replace('\\', '/');
                File f = new File(exdir, fn);
                if (en.isDirectory()) { f.mkdirs(); continue; }
                File parent = f.getParentFile();
                if (parent != null) parent.mkdirs();
                FileOutputStream fos = new FileOutputStream(f);
                int r;
                while ((r = rd.read(buf)) > 0) fos.write(buf, 0, r);
                fos.close();
            }
            rd.close();
            // 2) 复制新文件到根（平铺）
            File[] add = addDir.listFiles();
            if (add != null) for (File f : add) {
                File dst = new File(exdir, f.getName());
                copyFile(f, dst);
            }
            // 3) 重写 7z
            SevenZOutputFile sz = (pw != null && pw.length() > 0)
                    ? new SevenZOutputFile(nw, pw.toCharArray()) : new SevenZOutputFile(nw);
            LZMA2Options lo = new LZMA2Options(lv >= 9 ? LZMA2Options.PRESET_MAX : lv);
            if (lv >= 9) lo.setDictSize(1 << 24);
            sz.setContentMethods(Collections.singletonList(
                    new SevenZMethodConfiguration(SevenZMethod.LZMA2, lo)));
            File[] tops = exdir.listFiles();
            if (tops != null) for (File t : tops) addTo7z(sz, t, "");
            sz.close();
            copyFile(nw, old);
        } finally {
            deleteRecursive(exdir);
            nw.delete();
        }
    }

    private void mgrDeletePrompt() {
        try {
            final ArrayList<String> names = new ArrayList<String>();
            if ("zip".equals(mgrType)) {
                ZipFile zf = new ZipFile(mgrFile);
                if (passInput.getText().length() > 0) zf.setPassword(passInput.getText().toString().toCharArray());
                List<FileHeader> hs = zf.getFileHeaders();
                for (FileHeader h : hs) if (!h.isDirectory()) names.add(h.getFileName());
                zf.close();
            } else {
                SevenZFile sf = passInput.getText().length() > 0
                        ? new SevenZFile(mgrFile, passInput.getText().toString().toCharArray())
                        : new SevenZFile(mgrFile);
                SevenZArchiveEntry e;
                while ((e = sf.getNextEntry()) != null) if (!e.isDirectory()) names.add(e.getName());
                sf.close();
            }
            if (names.isEmpty()) { log("没有可删除的文件条目。"); return; }
            final boolean[] checked = new boolean[names.size()];
            new AlertDialog.Builder(this).setTitle("选择要删除的条目")
                    .setMultiChoiceItems(names.toArray(new String[0]), checked, new DialogInterface.OnMultiChoiceClickListener() {
                        public void onClick(DialogInterface d, int which, boolean isc) { checked[which] = isc; }
                    })
                    .setPositiveButton("删除选中", new DialogInterface.OnClickListener() {
                        public void onClick(DialogInterface d, int w) {
                            final ArrayList<String> sel = new ArrayList<String>();
                            for (int i = 0; i < checked.length; i++) if (checked[i]) sel.add(names.get(i));
                            if (sel.isEmpty()) return;
                            new Thread(new Runnable() { public void run() {
                                try { mgrDelete(sel); } catch (Exception e) { log("删除错误: " + e); }
                            }}).start();
                        }
                    }).setNegativeButton("取消", null).show();
        } catch (Exception e) {
            log("列条目失败（可能需要密码）: " + e.getMessage());
        }
    }

    private void mgrDelete(ArrayList<String> names) throws Exception {
        String pw = passInput.getText().toString();
        if ("zip".equals(mgrType)) {
            ZipFile zf = new ZipFile(mgrFile);
            if (pw != null && pw.length() > 0) zf.setPassword(pw.toCharArray());
            for (String n : names) zf.removeFile(n);
            zf.close();
            log("已从 zip 删除 " + names.size() + " 个条目。");
        } else {
            // 7z：读出后过滤重写
            File old = mgrFile;
            File nw = new File(getCacheDir(), "mgr7d_" + UUID.randomUUID().toString() + ".7z");
            File exdir = new File(getCacheDir(), "mgr7dx_" + UUID.randomUUID().toString());
            exdir.mkdirs();
            try {
                SevenZFile rd = (pw != null && pw.length() > 0)
                        ? new SevenZFile(old, pw.toCharArray()) : new SevenZFile(old);
                SevenZArchiveEntry en;
                byte[] buf = new byte[65536];
                while ((en = rd.getNextEntry()) != null) {
                    String fn = en.getName().replace('\\', '/');
                    if (en.isDirectory()) { new File(exdir, fn).mkdirs(); continue; }
                    File f = new File(exdir, fn);
                    File parent = f.getParentFile();
                    if (parent != null) parent.mkdirs();
                    FileOutputStream fos = new FileOutputStream(f);
                    int r;
                    while ((r = rd.read(buf)) > 0) fos.write(buf, 0, r);
                    fos.close();
                }
                rd.close();
                for (String n : names) {
                    File f = new File(exdir, n);
                    if (f.exists()) f.delete();
                }
                SevenZOutputFile sz = (pw != null && pw.length() > 0)
                        ? new SevenZOutputFile(nw, pw.toCharArray()) : new SevenZOutputFile(nw);
                LZMA2Options lo = new LZMA2Options(9);
                lo.setDictSize(1 << 24);
                sz.setContentMethods(Collections.singletonList(
                        new SevenZMethodConfiguration(SevenZMethod.LZMA2, lo)));
                File[] tops = exdir.listFiles();
                if (tops != null) for (File t : tops) addTo7z(sz, t, "");
                sz.close();
                copyFile(nw, old);
                log("已从 7z 删除 " + names.size() + " 个条目（重打包）。");
            } finally {
                deleteRecursive(exdir);
                nw.delete();
            }
        }
        mgrList();
    }

    private void mgrCommentPrompt() {
        if (!"zip".equals(mgrType)) { log("注释仅 .zip 支持（7z 格式无注释）。"); return; }
        final EditText et = new EditText(this);
        try {
            ZipFile zf = new ZipFile(mgrFile);
            String c = zf.getComment();
            if (c != null) et.setText(c);
            zf.close();
        } catch (Exception ignored) {}
        new AlertDialog.Builder(this).setTitle("设置 zip 注释")
                .setView(et)
                .setPositiveButton("保存", new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface d, int w) {
                        final String comment = et.getText().toString();
                        new Thread(new Runnable() { public void run() {
                            try {
                                ZipFile zf = new ZipFile(mgrFile);
                                zf.setComment(comment);
                                zf.close();
                                log("zip 注释已设置。");
                                mgrList();
                            } catch (Exception e) { log("注释设置失败: " + e.getMessage()); }
                        }}).start();
                    }
                }).setNegativeButton("取消", null).show();
    }

    private void mgrSaveAndClose() {
        if (mgrFile == null) return;
        try {
            // 以原文件名发布到下载目录
            String outName = "edited_" + System.currentTimeMillis()
                    + ("zip".equals(mgrType) ? ".zip" : ".7z");
            publishFile(mgrFile, outName);
            log("已保存修改后的压缩包: " + outName);
            mgrFile = null;
            mgrType = null;
        } catch (Exception e) {
            log("保存失败: " + e.getMessage());
        }
    }

    private void copyFile(File src, File dst) throws Exception {
        File parent = dst.getParentFile();
        if (parent != null) parent.mkdirs();
        FileInputStream in = new FileInputStream(src);
        FileOutputStream out = new FileOutputStream(dst);
        byte[] buf = new byte[65536];
        int n;
        while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        in.close();
        out.close();
    }

    private static String trimSlash(String s) {
        if (s == null) return "";
        return s.endsWith("/") ? s.substring(0, s.length() - 1) : s;
    }

    private void deliver(File result, boolean isDir, String displayName) throws Exception {
        if (extractTreeUri != null) {
            String rootId = DocumentsContract.getTreeDocumentId(extractTreeUri);
            Uri rootDoc = DocumentsContract.buildDocumentUriUsingTree(extractTreeUri, rootId);
            if (isDir) {
                String folderName = trimSlash(displayName);
                Uri target = safCreateDir(rootDoc, folderName);
                safWriteTree(result, target);
            } else {
                safWriteFile(result, rootDoc, result.getName());
            }
            log("已解压到所选目录: " + (isDir ? trimSlash(displayName) : result.getName()));
            deleteRecursive(result);
        } else {
            if (isDir) {
                publishTreeToMedia(result, displayName);
            } else {
                publishMediaFile(result, "", result.getName());
                result.delete();
            }
        }
    }

    private void publishTreeToMedia(File dir, String rel) throws Exception {
        File[] kids = dir.listFiles();
        if (kids != null) {
            for (File f : kids) {
                if (f.isDirectory()) publishTreeToMedia(f, rel + f.getName() + "/");
                else publishMediaFile(f, rel, f.getName());
            }
        }
        deleteRecursive(dir);
    }

    private Uri safCreateDir(Uri parent, String name) throws Exception {
        String pid = DocumentsContract.getDocumentId(parent);
        Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(extractTreeUri, pid);
        Cursor c = getContentResolver().query(children,
                new String[]{DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                        DocumentsContract.Document.COLUMN_DISPLAY_NAME}, null, null, null);
        if (c != null) {
            try {
                while (c.moveToNext()) {
                    if (name.equals(c.getString(1)))
                        return DocumentsContract.buildDocumentUriUsingTree(extractTreeUri, c.getString(0));
                }
            } finally { c.close(); }
        }
        Uri d = DocumentsContract.createDocument(getContentResolver(), parent,
                DocumentsContract.Document.MIME_TYPE_DIR, name);
        if (d == null) throw new IOException("无法创建目录: " + name);
        return d;
    }

    private void safWriteTree(File dir, Uri dirUri) throws Exception {
        File[] kids = dir.listFiles();
        if (kids == null) return;
        for (File f : kids) {
            if (f.isDirectory()) {
                Uri sub = safCreateDir(dirUri, f.getName());
                safWriteTree(f, sub);
            } else {
                safWriteFile(f, dirUri, f.getName());
            }
        }
    }

    private void safWriteFile(File f, Uri parentDir, String name) throws Exception {
        String mime = mimeOf(name);
        Uri existing = safFindChild(parentDir, name);
        if (existing != null) {
            try { DocumentsContract.deleteDocument(getContentResolver(), existing); } catch (Exception ignored) {}
        }
        Uri doc = DocumentsContract.createDocument(getContentResolver(), parentDir, mime, name);
        if (doc == null) { log("SAF 无法写入: " + name); return; }
        OutputStream os = getContentResolver().openOutputStream(doc);
        FileInputStream fis = new FileInputStream(f);
        byte[] buf = new byte[65536];
        int n;
        while ((n = fis.read(buf)) > 0) os.write(buf, 0, n);
        fis.close();
        os.close();
    }

    private Uri safFindChild(Uri parent, String name) {
        String pid = DocumentsContract.getDocumentId(parent);
        Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(extractTreeUri, pid);
        Cursor c = getContentResolver().query(children,
                new String[]{DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                        DocumentsContract.Document.COLUMN_DISPLAY_NAME}, null, null, null);
        if (c != null) {
            try {
                while (c.moveToNext()) {
                    if (name.equals(c.getString(1)))
                        return DocumentsContract.buildDocumentUriUsingTree(extractTreeUri, c.getString(0));
                }
            } finally { c.close(); }
        }
        return null;
    }

    private String mimeOf(String name) {
        int i = name.lastIndexOf('.');
        if (i >= 0) {
            String ext = name.substring(i + 1).toLowerCase();
            String m = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext);
            if (m != null) return m;
        }
        return "application/octet-stream";
    }

    private void copyUriToFile(Uri uri, File dst) throws Exception {
        InputStream in = getContentResolver().openInputStream(uri);
        if (in == null) throw new IOException("无法读取输入");
        FileOutputStream fos = new FileOutputStream(dst);
        byte[] buf = new byte[65536];
        int n;
        while ((n = in.read(buf)) > 0) fos.write(buf, 0, n);
        in.close();
        fos.close();
    }

    private void publishMediaFile(File f, String subDir, String name) throws Exception {
        ContentValues cv = new ContentValues();
        cv.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
        cv.put(MediaStore.MediaColumns.MIME_TYPE, mimeOf(name));
        cv.put(MediaStore.MediaColumns.RELATIVE_PATH,
                Environment.DIRECTORY_DOWNLOADS + "/XZFull/" + subDir);
        Uri outUri = getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cv);
        if (outUri == null) { log("写入 MediaStore 失败: " + name); return; }
        OutputStream out = getContentResolver().openOutputStream(outUri);
        FileInputStream fis = new FileInputStream(f);
        byte[] buf = new byte[65536];
        int n;
        while ((n = fis.read(buf)) > 0) out.write(buf, 0, n);
        fis.close();
        out.close();
    }

    private void publishFile(File f, String displayName) throws Exception {
        publishMediaFile(f, "", displayName);
        try { f.delete(); } catch (Exception ignored) {}
    }

    private String queryName(Uri uri) {
        String n = "file";
        try {
            Cursor c = getContentResolver().query(uri, null, null, null, null);
            if (c != null) {
                if (c.moveToFirst()) {
                    int idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                    if (idx >= 0 && c.getString(idx) != null) n = c.getString(idx);
                }
                c.close();
            }
        } catch (Exception ignored) { }
        if ("file".equals(uri.getScheme()) || n == null || n.length() == 0) {
            String seg = uri.getLastPathSegment();
            if (seg != null && seg.length() > 0) n = seg;
        }
        return n;
    }

    private String queryTreeName(Uri treeUri) {
        try {
            String id = DocumentsContract.getTreeDocumentId(treeUri);
            int colon = id.lastIndexOf(':');
            String tail = colon >= 0 ? id.substring(colon + 1) : id;
            if (tail.length() > 0) {
                int slash = tail.lastIndexOf('/');
                if (slash >= 0) tail = tail.substring(slash + 1);
                if (tail.length() > 0) return tail;
            }
            return id;
        } catch (Exception e) {
            return "folder";
        }
    }

    private String safeName(String n) {
        if (n == null) return "file";
        return n.replace('\\', '_').replace('/', '_').replace(':', '_').replace('*', '_')
                .replace('?', '_').replace('"', '_').replace('<', '_').replace('>', '_').replace('|', '_');
    }

    private String uniqueName(File dir, String name) {
        if (!new File(dir, name).exists()) return name;
        int dot = name.lastIndexOf('.');
        String base = dot > 0 ? name.substring(0, dot) : name;
        String ext = dot > 0 ? name.substring(dot) : "";
        for (int i = 1; i < 10000; i++) {
            String cand = base + "_" + i + ext;
            if (!new File(dir, cand).exists()) return cand;
        }
        return base + "_" + System.nanoTime() + ext;
    }

    private void deleteRecursive(File f) {
        if (f == null || !f.exists()) return;
        if (f.isDirectory()) {
            File[] kids = f.listFiles();
            if (kids != null) for (File k : kids) deleteRecursive(k);
        }
        f.delete();
    }

    private Uri createOutput(String fileName) {
        ContentValues cv = new ContentValues();
        cv.put(MediaStore.MediaColumns.DISPLAY_NAME, fileName);
        cv.put(MediaStore.MediaColumns.MIME_TYPE, "application/octet-stream");
        cv.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/XZFull");
        return getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cv);
    }

    private void log(final String s) {
        Log.i(TAG, s);
        runOnUiThread(new Runnable() {
            public void run() {
                logView.append("\n" + s);
            }
        });
    }

    private void showAbout() {
        String msg =
            "XZ 完整压缩 早期测试版 0.1（安卓完整版）\n\n" +
            "压缩：xz / 7z / zip(AES-256) / tar.xz / tar.gz / gz / bz2，三档 L3/6/9\n" +
            "解压：xz/zip/7z/rar/tar.xz/tgz/gz/bz2/tar（含加密）\n" +
            "管理：列表、解压、追加、删除、zip 注释、完整性测试\n\n" +
            "所有处理在本机完成，文件不上传。\n\n" +
            "开源组件与许可：\n" +
            "• XZ for Java（org.tukaani:xz）— 公共领域/0BSD\n" +
            "• Apache Commons Compress / Commons IO — Apache 2.0\n" +
            "• Zip4j — Apache 2.0（AES-256）\n" +
            "• junrar — UnRAR License（仅解压 RAR，禁止重建 RAR 算法）\n" +
            "完整文本见随发行包 THIRD-PARTY-LICENSES.md。";
        new AlertDialog.Builder(this).setTitle("关于 / 开源许可").setMessage(msg)
                .setPositiveButton("确定", null).show();
    }

    private void extractTools() {
        try {
            String[] names = {"commons-compress.jar", "commons-io.jar", "junrar.jar", "zip4j.jar"};
            File outDir = new File(getExternalFilesDir(null), "tools");
            if (!outDir.exists()) outDir.mkdirs();
            StringBuilder sb = new StringBuilder();
            for (String n : names) {
                try {
                    InputStream is = getAssets().open(n);
                    File out = new File(outDir, n);
                    FileOutputStream fos = new FileOutputStream(out);
                    byte[] buf = new byte[65536];
                    int r;
                    while ((r = is.read(buf)) > 0) fos.write(buf, 0, r);
                    fos.close();
                    is.close();
                    sb.append(n).append(" OK, ");
                } catch (Exception en) {
                    sb.append(n).append(" 缺失, ");
                }
            }
            log("工具库已解出到: " + outDir.getAbsolutePath() + "  (" + sb.toString() + ")");
        } catch (final Exception e) {
            log("工具解出失败: " + e.getMessage());
        }
    }
}
