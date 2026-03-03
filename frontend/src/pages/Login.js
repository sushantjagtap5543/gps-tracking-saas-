import { useState, useContext } from "react";
import API from "../api";
import { AuthContext } from "../context/AuthContext";

export default function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const { login } = useContext(AuthContext);

  const handleLogin = async () => {
    try {
      const res = await API.post("/auth/login", { email, password });
      login(res.data.token);
    } catch (err) {
      alert("Login failed");
    }
  };

  return (
    <div style={{ padding: 50 }}>
      <h2>Login</h2>
      <input placeholder="Email" onChange={(e) => setEmail(e.target.value)} />
      <br /><br />
      <input type="password" placeholder="Password" onChange={(e) => setPassword(e.target.value)} />
      <br /><br />
      <button onClick={handleLogin}>Login</button>
    </div>
  );
}
