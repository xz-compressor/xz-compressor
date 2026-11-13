package com.xzport;

import android.Manifest;
import android.app.Activity;
import android.content.ContentUris;
import android.content.ContentValues;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import org.tukaani.xz.XZInputStream;
import org.apache.commons.compress.archivers.tar.TarArchiveEntry;
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream;
import org.apache.commons.compress.archivers.sevenz.SevenZArchiveEntry;
import org.apache.commons.compress.archivers.sevenz.SevenZFile;
import net.lingala.zip4j.ZipFile;
import net.lingala.zip4j.model.FileHeader;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.List;
import java.util.UUID;

/**
 * XZ 便携压缩 - 自解压安装包（早期测试版 0.1）
 * 内置 payload（res/raw，无扩展名），魔数识别 zip / 7z / tar.xz，
 * 一键解压到 下载/XZPort 目录；zip/7z 支持密码（在输入框填写）。
 */
public class MainActivity extends Activity {

    private TextView infoView;
    private EditText passInput;
    private static final int REQ_WRITE = 1001;
    private static final String OUT_DIR = "XZPort";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        int pad = dp(24);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        root.setPadding(pad, pad, pad, pad);

        TextView title = new TextView(this);
        title.setText("XZ 便携压缩工具 早期测试版 0.1");
        title.setTextSize(20);
        root.addView(title);

        infoView = new TextView(this);
        infoView.setTextSize(14);
        infoView.setPadding(0, dp(16), 0, dp(16));
        infoView.setGravity(Gravity.CENTER);
        root.addView(infoView);

        passInput = new EditText(this);
        passInput.setHint("如压缩包已加密，请在此输入密码");
        root.addView(passInput);

        Button btn = new Button(this);
        btn.setText("一键解压到 下载 目录");
        root.addView(btn);

        TextView tip = new TextView(this);
        tip.setTextSize(12);
        tip.setPadding(0, dp(12), 0, 0);
        tip.setText("支持 .zip / .7z / .tar.xz（xz）格式");
        root.addView(tip);

        setContentView(root);

        btn.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                if (Build.VERSION.SDK_INT < 29
                        && checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                        != PackageManager.PERMISSION_GRANTED) {
                    requestPermissions(new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE}, REQ_WRITE);
                    return;
                }
                startExtract();
            }
        });

        showInfo();

        if (getIntent().getBooleanExtra("auto_extract", false)) {
            btn.postDelayed(new Runnable() {
                @Override public void run() { startExtract(); }
            }, 600);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQ_WRITE) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startExtract();
            } else {
                toast("未授予存储权限，无法解压");
            }
        }
    }

    private void showInfo() {
        try {
            InputStream in = getResources().openRawResource(R.raw.payload);
            byte[] head = new byte[6];
            int r = in.read(head);
            in.close();
            String fmt = detect(head, r);
            infoView.setText("内置压缩数据类型: " + fmt);
        } catch (Exception e) {
            infoView.setText("内置压缩数据读取失败");
        }
    }

    private void startExtract() {
        String extraPw = getIntent().getStringExtra("password");
        final String pw = (extraPw != null && extraPw.length() > 0)
                ? extraPw : passInput.getText().toString();
        new Thread(new Runnable() {
            @Override public void run() {
                try {
                    doExtract(pw);
                } catch (final Throwable e) {
                    android.util.Log.e("XZPORT", "extract failed", e);
                    String msg = e.getClass().getName() + ": " + e.getMessage();
                    Throwable cause = e.getCause();
                    while (cause != null) {
                        msg += " | caused by " + cause.getClass().getName() + ": " + cause.getMessage();
                        cause = cause.getCause();
                    }
                    final String fmsg = msg;
                    showToastOnUi("解压失败: " + fmsg);
                }
            }
        }).start();
    }

    private String friendly(Exception e) {
        String m = e.getMessage();
        if (m != null && (m.toLowerCase().contains("password") || m.toLowerCase().contains("密码")
                || m.toLowerCase().contains("auth") || m.toLowerCase().contains("encrypt")
                || m.toLowerCase().contains("wrong"))) {
            return "密码错误或压缩包已加密";
        }
        return m == null ? e.getClass().getName() : m;
    }

    private void doExtract(String password) throws Exception {
        File tmp = new File(getCacheDir(), "payload_" + UUID.randomUUID().toString());
        File outTmp = new File(getCacheDir(), "out_" + UUID.randomUUID().toString());
        outTmp.mkdirs();
        try {
            InputStream raw = getResources().openRawResource(R.raw.payload);
            FileOutputStream fos = new FileOutputStream(tmp);
            copy(raw, fos);
            fos.close();
            raw.close();

            byte[] head = new byte[6];
            FileInputStream fis = new FileInputStream(tmp);
            int rn = fis.read(head);
            fis.close();
            String fmt = detect(head, rn);

            int count;
            if ("zip".equals(fmt)) {
                count = extractZip(tmp, outTmp, password);
            } else if ("7z".equals(fmt)) {
                count = extract7z(tmp, outTmp, password);
            } else if ("xz".equals(fmt)) {
                count = extractXz(tmp, outTmp);
            } else {
                throw new Exception("不支持的压缩格式（魔数不识别）");
            }

            publishDir(outTmp, "");
            final int fc = count;
            showToastOnUi("解压完成: " + fc + " 个文件\n位置: 下载/" + OUT_DIR);
        } finally {
            tmp.delete();
            deleteRecursive(outTmp);
        }
    }

    private String detect(byte[] h, int len) {
        if (len >= 4 && (h[0] & 0xFF) == 0x50 && (h[1] & 0xFF) == 0x4B
                && (h[2] & 0xFF) == 0x03 && (h[3] & 0xFF) == 0x04) {
            return "zip";
        }
        if (len >= 6 && (h[0] & 0xFF) == 0x37 && (h[1] & 0xFF) == 0x7A
                && (h[2] & 0xFF) == 0xBC && (h[3] & 0xFF) == 0xAF
                && (h[4] & 0xFF) == 0x27 && (h[5] & 0xFF) == 0x1C) {
            return "7z";
        }
        if (len >= 6 && (h[0] & 0xFF) == 0xFD && (h[1] & 0xFF) == 0x37
                && (h[2] & 0xFF) == 0x7A && (h[3] & 0xFF) == 0x58
                && (h[4] & 0xFF) == 0x5A && (h[5] & 0xFF) == 0x00) {
            return "xz";
        }
        return "unknown";
    }

    private int extractZip(File tmp, File outTmp, String password) throws Exception {
        ZipFile zf = new ZipFile(tmp);
        if (password != null && password.length() > 0) {
            zf.setPassword(password.toCharArray());
        }
        int count = 0;
        List headers = zf.getFileHeaders();
        for (int i = 0; i < headers.size(); i++) {
            FileHeader h = (FileHeader) headers.get(i);
            if (h.isDirectory()) continue;
            String name = h.getFileName();
            File out = new File(outTmp, name);
            File parent = out.getParentFile();
            if (parent != null) parent.mkdirs();
            InputStream is = zf.getInputStream(h);
            FileOutputStream os = new FileOutputStream(out);
            copy(is, os);
            os.close();
            is.close();
            count++;
        }
        zf.close();
        return count;
    }

    private int extract7z(File tmp, File outTmp, String password) throws Exception {
        SevenZFile sz = (password != null && password.length() > 0)
                ? new SevenZFile(tmp, password.toCharArray())
                : new SevenZFile(tmp);
        int count = 0;
        byte[] buf = new byte[65536];
        SevenZArchiveEntry entry;
        while ((entry = sz.getNextEntry()) != null) {
            if (entry.isDirectory()) continue;
            String name = entry.getName();
            File out = new File(outTmp, name);
            File parent = out.getParentFile();
            if (parent != null) parent.mkdirs();
            FileOutputStream os = new FileOutputStream(out);
            int n;
            while ((n = sz.read(buf)) > 0) {
                os.write(buf, 0, n);
            }
            os.close();
            count++;
        }
        sz.close();
        return count;
    }

    /** 解 tar.xz（文件夹/多文件）；若内层是单个 tar 流则按 tar 条目；纯 xz 解为单文件 */
    private int extractXz(File tmp, File outTmp) throws Exception {
        int count = 0;
        XZInputStream xz = new XZInputStream(new FileInputStream(tmp));
        // 尝试作为 tar 流
        TarArchiveInputStream tis = new TarArchiveInputStream(xz);
        TarArchiveEntry te = tis.getNextTarEntry();
        if (te != null) {
            while (te != null) {
                if (!te.isDirectory()) {
                    String name = te.getName();
                    File out = new File(outTmp, name);
                    File parent = out.getParentFile();
                    if (parent != null) parent.mkdirs();
                    FileOutputStream os = new FileOutputStream(out);
                    copy(tis, os);
                    os.close();
                    count++;
                }
                te = tis.getNextTarEntry();
            }
            tis.close();
            if (count == 0) {
                throw new Exception("tar 包为空");
            }
            return count;
        }
        tis.close();
        // 纯单文件 xz
        File out = new File(outTmp, "data");
        FileOutputStream os = new FileOutputStream(out);
        XZInputStream xz2 = new XZInputStream(new FileInputStream(tmp));
        copy(xz2, os);
        os.close();
        xz2.close();
        return 1;
    }

    // ============ 发布到 下载/XZPort (MediaStore) ============
    private void publishDir(File dir, String relBase) throws Exception {
        cleanOld();
        publishDirInner(dir, relBase);
    }

    private void publishDirInner(File dir, String relBase) throws Exception {
        File[] files = dir.listFiles();
        if (files == null) return;
        for (File f : files) {
            if (f.isDirectory()) {
                publishDirInner(f, relBase + f.getName() + "/");
            } else {
                publishFile(f, relBase + f.getName());
            }
        }
    }

    private void publishFile(File f, String relAfterOut) throws Exception {
        String rel = Environment.DIRECTORY_DOWNLOADS + "/" + OUT_DIR + "/" + relAfterOut;
        // 保证子目录存在：RELATIVE_PATH 以 / 结尾
        int slash = relAfterOut.lastIndexOf('/');
        String dirRel = Environment.DIRECTORY_DOWNLOADS + "/" + OUT_DIR + "/";
        if (slash >= 0) {
            dirRel = Environment.DIRECTORY_DOWNLOADS + "/" + OUT_DIR + "/"
                    + relAfterOut.substring(0, slash + 1);
        }
        String display = slash >= 0 ? relAfterOut.substring(slash + 1) : relAfterOut;
        ContentValues cv = new ContentValues();
        cv.put(MediaStore.MediaColumns.DISPLAY_NAME, display);
        cv.put(MediaStore.MediaColumns.MIME_TYPE, guessMime(display));
        cv.put(MediaStore.MediaColumns.RELATIVE_PATH, dirRel);
        Uri uri = getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cv);
        if (uri == null) {
            // 回退：直接放到 XZPort 根
            cv.put(MediaStore.MediaColumns.RELATIVE_PATH,
                    Environment.DIRECTORY_DOWNLOADS + "/" + OUT_DIR + "/");
            uri = getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cv);
        }
        if (uri == null) return;
        OutputStream os = getContentResolver().openOutputStream(uri);
        FileInputStream fis = new FileInputStream(f);
        copy(fis, os);
        os.close();
        fis.close();
    }

    private void cleanOld() {
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                String rel = Environment.DIRECTORY_DOWNLOADS + "/" + OUT_DIR + "/";
                Uri collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI;
                Cursor cur = getContentResolver().query(collection,
                        new String[]{MediaStore.Downloads._ID},
                        MediaStore.Downloads.RELATIVE_PATH + " LIKE ?",
                        new String[]{rel + "%"}, null);
                if (cur != null) {
                    while (cur.moveToNext()) {
                        long id = cur.getLong(0);
                        getContentResolver().delete(
                                ContentUris.withAppendedId(collection, id), null, null);
                    }
                    cur.close();
                }
            }
        } catch (Exception e) {
            // 清理失败不阻塞解压
        }
    }

    private void deleteRecursive(File f) {
        if (f == null || !f.exists()) return;
        if (f.isDirectory()) {
            File[] fs = f.listFiles();
            if (fs != null) for (File c : fs) deleteRecursive(c);
        }
        f.delete();
    }

    private void copy(InputStream in, OutputStream out) throws Exception {
        byte[] buf = new byte[65536];
        int n;
        while ((n = in.read(buf)) > 0) {
            out.write(buf, 0, n);
        }
    }

    private String guessMime(String name) {
        String n = name.toLowerCase();
        if (n.endsWith(".apk")) return "application/vnd.android.package-archive";
        if (n.endsWith(".txt")) return "text/plain";
        if (n.endsWith(".html") || n.endsWith(".htm")) return "text/html";
        if (n.endsWith(".jpg") || n.endsWith(".jpeg")) return "image/jpeg";
        if (n.endsWith(".png")) return "image/png";
        if (n.endsWith(".gif")) return "image/gif";
        if (n.endsWith(".mp3")) return "audio/mpeg";
        if (n.endsWith(".mp4")) return "video/mp4";
        if (n.endsWith(".zip")) return "application/zip";
        if (n.endsWith(".pdf")) return "application/pdf";
        if (n.endsWith(".doc")) return "application/msword";
        if (n.endsWith(".docx")) return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
        if (n.endsWith(".ppt")) return "application/vnd.ms-powerpoint";
        if (n.endsWith(".pptx")) return "application/vnd.openxmlformats-officedocument.presentationml.presentation";
        if (n.endsWith(".xls")) return "application/vnd.ms-excel";
        if (n.endsWith(".xlsx")) return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
        if (n.endsWith(".csv")) return "text/csv";
        return "application/octet-stream";
    }

    private int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density + 0.5f);
    }

    private void toast(final String msg) {
        Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
    }

    private void showToastOnUi(final String msg) {
        runOnUiThread(new Runnable() {
            @Override public void run() { toast(msg); }
        });
    }
}
