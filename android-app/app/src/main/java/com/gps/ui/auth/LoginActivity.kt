package com.gps.ui.auth

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.gps.LiveMapActivity
import android.content.Intent
// Assume layout with email/pass button

class LoginActivity : AppCompatActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.activity_login); // Create basic layout

    // On button click
    startActivity(Intent(this, LiveMapActivity::class.java));
  }
}
