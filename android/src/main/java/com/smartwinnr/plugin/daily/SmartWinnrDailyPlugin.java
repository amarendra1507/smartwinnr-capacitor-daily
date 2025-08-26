package com.smartwinnr.plugin.daily;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import android.graphics.Color;
import android.view.ViewGroup;
import com.getcapacitor.Logger;

@CapacitorPlugin(name = "SmartWinnrDaily")
public class SmartWinnrDailyPlugin extends Plugin {

    private static final String ERROR_COLOR_MISSING = "color must be provided.";
    private static final String TAG = "SmartWinnrDaily";


    private SmartWinnrDaily implementation;

    @Override
    public void load() {
        SmartWinnrDailyConfig config = getSmartWinnrDailyConfig();
        implementation = new SmartWinnrDaily(this, config);
    }

    @PluginMethod
    public void enable(PluginCall call) {
        String color = call.getString("color");
        
        getActivity()
            .runOnUiThread(() -> {
                try {
                    implementation.enable();
                    
                    // If color is provided, use it; otherwise use the default from config
                    if (color != null) {
                        implementation.setBackgroundColor(color);
                    } else {
                        // Use the default background color from config
                        SmartWinnrDailyConfig config = getSmartWinnrDailyConfig();
                        // Convert the int color to hex string for the setBackgroundColor method
                        String defaultColorHex = String.format("#%06X", (0xFFFFFF & config.getBackgroundColor()));
                        implementation.setBackgroundColor(defaultColorHex);
                    }
                    
                    call.resolve();
                } catch (Exception exception) {
                    call.reject(exception.getMessage());
                }
            });
    }

    @PluginMethod
    public void disable(PluginCall call) {
        getActivity()
            .runOnUiThread(() -> {
                try {
                    implementation.disable();
                    call.resolve();
                } catch (Exception exception) {
                    call.reject(exception.getMessage());
                }
            });
    }

    @PluginMethod
    public void getInsets(PluginCall call) {
        try {
            ViewGroup.MarginLayoutParams insets = implementation.getInsets();
            JSObject result = new JSObject();
            result.put("bottom", insets.bottomMargin);
            result.put("left", insets.leftMargin);
            result.put("right", insets.rightMargin);
            result.put("top", insets.topMargin);
            call.resolve(result);
        } catch (Exception exception) {
            call.reject(exception.getMessage());
        }
    }

    @PluginMethod
    public void setBackgroundColor(PluginCall call) {
        String color = call.getString("color");
        if (color == null) {
            call.reject(ERROR_COLOR_MISSING);
            return;
        }
        getActivity()
            .runOnUiThread(() -> {
                try {
                    implementation.setBackgroundColor(color);
                    call.resolve();
                } catch (Exception exception) {
                    call.reject(exception.getMessage());
                }
            });
    }

    private SmartWinnrDailyConfig getSmartWinnrDailyConfig() {
        SmartWinnrDailyConfig config = new SmartWinnrDailyConfig();

        try {
            String backgroundColor = getConfig().getString("backgroundColor");
            if (backgroundColor != null) {
                config.setBackgroundColor(Color.parseColor(backgroundColor));
            }
        } catch (Exception exception) {
            Logger.error(TAG, "Set config failed.", exception);
        }
        return config;
    }
}
