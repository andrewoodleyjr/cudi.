package com.andrewoodleyjr.cudi;

import android.Manifest;
import android.app.Dialog;
import android.app.ProgressDialog;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.res.AssetManager;
import android.database.Cursor;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.os.Environment;
import android.provider.DocumentsContract;
import android.provider.MediaStore;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.NumberPicker;
import android.widget.TextView;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;

import nl.bravobit.ffmpeg.ExecuteBinaryResponseHandler;
import nl.bravobit.ffmpeg.FFmpeg;

public class MainActivity extends AppCompatActivity {

    TextView timerTxt;
    Float duration;
    SharedPreferences preferences;
    SharedPreferences.Editor editor;
    String TAG = "main";
    FFmpeg ffmpeg;
    Integer MY_PERMISSIONS_REQUEST_READ_MEDIA = 0;
    Integer REQUEST_TAKE_GALLERY_VIDEO = 1;
    ProgressDialog progress;
    Context context;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        setTheme(R.style.AppTheme);
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        context = MainActivity.this;
        setContentView(R.layout.activity_main);
        timerTxt = (TextView) findViewById(R.id.timeTxt);
        progress = new ProgressDialog(context);
        progress.setTitle("Loading");
        progress.setMessage("hold up, chopping video...\nkeep the app open");
        progress.setCancelable(false); // disable dismiss by tapping outside of the dialog
        preferences = this.getSharedPreferences("CUDI_PREFERENCES", Context.MODE_PRIVATE);
        loadFFmpeg();
        loadDuration();
        createWatermark();
        int permissionCheck = ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE);
        if (permissionCheck != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE}, MY_PERMISSIONS_REQUEST_READ_MEDIA);
        }
    }

    public void createWatermark() {
        String out= Environment.getExternalStorageDirectory().getAbsolutePath() + "/cudi/assets/" ;
        File file = new File(out, "watermarksmall.png");
        if(file.exists()){
            // Do Nothing

        } else {
            file = new File(out);
            file.mkdirs();
            copyAssets();
        }

        out= Environment.getExternalStorageDirectory().getAbsolutePath() + "/cudi/videos/" ;
        file = new File(out);
        file.mkdirs();
    }

    private void copyAssets() {
        AssetManager assetManager = getAssets();
        String[] files = null;
        try {
            files = assetManager.list("");
        } catch (IOException e) {
            Log.e("tag", "Failed to get asset file list.", e);
        }
        for(String filename : files) {
            InputStream in = null;
            OutputStream out = null;
            try {
                in = assetManager.open(filename);
                String outDir = Environment.getExternalStorageDirectory().getAbsolutePath() + "/cudi/assets/" ;
                File outFile = new File(outDir, filename);
                out = new FileOutputStream(outFile);
                copyFile(in, out);
                in.close();
                in = null;
                out.flush();
                out.close();
                out = null;
            } catch(IOException e) {
                Log.e("tag", "Failed to copy asset file: " + filename, e);
            }
        }
    }

    private void copyFile(InputStream in, OutputStream out) throws IOException {
        byte[] buffer = new byte[1024];
        int read;
        while((read = in.read(buffer)) != -1){
            out.write(buffer, 0, read);
        }
    }

    public void loadFFmpeg(){
        if (FFmpeg.getInstance(context).isSupported()) {
            ffmpeg = FFmpeg.getInstance(context);
        } else {
            Log.d(TAG, "ffmpeg not supported");
        }
    }

    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (resultCode == RESULT_OK) {
            if (requestCode == REQUEST_TAKE_GALLERY_VIDEO) {
                Uri pickedVideoUri = data.getData();
                String pickedVideoUrl = getPath(pickedVideoUri);
                MediaMetadataRetriever retriever = new MediaMetadataRetriever();
                    retriever.setDataSource(context, data.getData());
                    String time = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
                    long videoTimeInMillisec = Long.parseLong(time );
                    retriever.release();
                    Log.d(TAG, Float.toString(videoTimeInMillisec));
                    Float videoTimeLimit = duration * 1000;
                    Integer numberOfVideoSplits = (int) Math.ceil(videoTimeInMillisec/videoTimeLimit);
                    Log.d(TAG, Integer.toString(numberOfVideoSplits));
                    for (int i = 1; i <= numberOfVideoSplits; i++){
                        Integer startTime = (int) ((i - 1) * videoTimeLimit);
                        Integer endTime = (int) (i * videoTimeLimit);
                        executeCutVideoCommand(startTime, endTime, pickedVideoUrl);
                    }
            }
        }
    }

    public String getPath(Uri uri) {
        String wholeID = DocumentsContract.getDocumentId(uri);
        String id = wholeID.split(":")[1];
        String[] column = { MediaStore.Video.Media.DATA };
        String sel = MediaStore.Video.Media._ID + "=?";
        Cursor cursor = getContentResolver().
                query(MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                        column, sel, new String[]{ id }, null);
        String filePath = "";
        int columnIndex = cursor.getColumnIndex(column[0]);
        if (cursor.moveToFirst()) {
            filePath = cursor.getString(columnIndex);
        }
        cursor.close();
        return filePath;
    }

    public void loadDuration() {
        Integer val = preferences.getInt("DURATION", 0);
        if(val == 0){
            updateTimeLabel(15);
            return;
        }
        String textLbl = Integer.toString(val) + " sec";
        timerTxt.setText(textLbl);
        duration = (float) val;
    }

    public void selectVideo(View view){
//        Intent intent = new Intent();
//        intent.setType("video/*");
//        intent.setAction(Intent.ACTION_GET_CONTENT);
//        startActivityForResult(Intent.createChooser(intent,"Select Video"), REQUEST_TAKE_GALLERY_VIDEO);
        Intent videoPickIntent = new Intent(Intent.ACTION_GET_CONTENT);
        videoPickIntent.setType("video/*");
        startActivityForResult(Intent.createChooser(videoPickIntent, "pick a video"), REQUEST_TAKE_GALLERY_VIDEO);
    }

    public void goToProfile(View view) {
        // Do something in response to button click
        Log.d(TAG, "Go To Profile");
        Uri uri = Uri.parse("http://instagram.com/_u/andrewoodleyjr");
        Intent likeIng = new Intent(Intent.ACTION_VIEW, uri);

        likeIng.setPackage("com.instagram.android");

        try {
            startActivity(likeIng);
        } catch (ActivityNotFoundException e) {
            startActivity(new Intent(Intent.ACTION_VIEW,
                    Uri.parse("http://instagram.com/andrewoodleyjr")));
        }
    }

    public void selectDuration(View view) {
        Log.d(TAG, "select video duration");

        final Dialog d = new Dialog(context);
        d.setTitle("Set Video Duration");
        d.setContentView(R.layout.dialog);
        Button okayBtn = (Button) d.findViewById(R.id.button1);
        Button cancelBtn = (Button) d.findViewById(R.id.button2);

        final NumberPicker numberPicker = (NumberPicker) d.findViewById(R.id.numberPicker1);
        final String[] arrayString = new String[]{
                "10 seconds *snapchat",
                "15 seconds *instagram",
                "20 seconds *facebook",
                "30 seconds *whatsapp",
                "45 seconds",
                "60 seconds"
        };
        numberPicker.setMinValue(0);
        numberPicker.setMaxValue(arrayString.length-1);
        numberPicker.setDisplayedValues(arrayString);
        numberPicker.setDescendantFocusability(NumberPicker.FOCUS_BLOCK_DESCENDANTS); // disable soft keyboard

        // set wrap true or false, try it you will know the difference
        numberPicker.setWrapSelectorWheel(false);
        okayBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                String val = arrayString[numberPicker.getValue()];
                updateTimeLabel(Integer.parseInt(val.substring(0, 2)));
                Log.d(TAG, val);
                d.dismiss();
            }
        });
        cancelBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                d.dismiss(); // dismiss the dialog
            }
        });
        d.show();
    }

    public void updateTimeLabel(Integer val) {
        editor = preferences.edit();
        editor.putInt("DURATION", val);
        editor.commit();
        loadDuration();
    }

    private void executeCutVideoCommand(int startMs, int endMs, String yourRealPath) {
        String timeStamp = new SimpleDateFormat("yyyy_MM_dd_HH_mm_ss_SSS").format(new Date());
        String filePrefix = "cudi_" + timeStamp;
        String fileExtn = ".mp4";
        String moviesDir= Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES).getAbsolutePath();
        File dest = new File(moviesDir, filePrefix + fileExtn);
        int fileNo = 0;
        while (dest.exists()) {
            fileNo++;
            dest = new File(moviesDir, filePrefix+ fileNo + fileExtn);
        }

        Log.d(TAG, "startTrim: src: " + yourRealPath);
        Log.d(TAG, "startTrim: dest: " + dest.getAbsolutePath());
        Log.d(TAG, "startTrim: startMs: " + startMs);
        Log.d(TAG, "startTrim: endMs: " + endMs);

        String filePath = dest.getAbsolutePath();
        String watermarkDir = Environment.getExternalStorageDirectory().getAbsolutePath() + "/cudi/assets/" ;

        File watermarkFile = new File(watermarkDir, "watermarksmall.png");
        String watermarkLocation = watermarkFile.getAbsolutePath();

        String[] complexCommand = {"-ss", "" + startMs / 1000, "-y", "-i", yourRealPath, "-i", watermarkLocation, "-filter_complex", "[0:v][1:v]overlay=30:main_h-overlay_h-150", "-t", "" + (endMs - startMs) / 1000, "-vcodec", "mpeg4",  "-b:v", "1000k", "-b:v", "2097152", "-b:a", "48000", "-ac", "2", "-ar", "22050", "-preset", "ultrafast", filePath}; // "-vcodec", "libx264", "-r", "24", "-an", "-f", "mp4", "-c:a", "copy","-preset", "ultrafast",
        execFFmpegBinary(complexCommand);
    }

    public void hideProgress(){
        if(progress.isShowing()){
            progress.dismiss();
        }
    }

    public void showProgress(){
        if(progress.isShowing() == false){
            progress.show();
        }
    }

    public void execFFmpegBinary(final String[] command) {
        try {
            ffmpeg.execute(command, new ExecuteBinaryResponseHandler() {
                @Override
                public void onFailure(String s) {
                    Log.d(TAG, "FAILED with output : " + s);
                }

                @Override
                public void onSuccess(String s) {
                    Log.d(TAG, "SUCCESS with output : " + s);
                    hideProgress();
                }

                @Override
                public void onProgress(String s) {
                    Log.d(TAG, "progress : " + s);
                    showProgress();
                }

                @Override
                public void onStart() {
                    Log.d(TAG, "Started command : ffmpeg " + command);
                    showProgress();
                }

                @Override
                public void onFinish() {
                    Log.d(TAG, "Finished command : ffmpeg " + command);
                    hideProgress();
                }
            });
        } catch (Error e) {
            // do nothing for now
            Log.d(TAG,e.toString());
        }
    }

}
