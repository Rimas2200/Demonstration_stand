import tkinter as tk
from tkinter import messagebox
import requests

ESP32_URL = "http://192.168.4.1/receive-path"
points = []


def draw_point(x, y):
    if points:
        last_point = points[-1]
        canvas.create_line(last_point["x"], last_point["y"], x, y, fill='blue', width=2)

    canvas.create_oval(x - 4, y - 4, x + 4, y + 4, fill='red')
    points.append({"x": x, "y": y})


def on_canvas_click(event):
    draw_point(event.x, event.y)


def send_to_esp32():
    if not points:
        messagebox.showwarning("Ошибка", "Нет точек для отправки!")
        return

    try:
        headers = {'Content-Type': 'application/json'}
        response = requests.post(ESP32_URL, json={"path": points}, headers=headers, timeout=5)
        if response.status_code == 200:
            messagebox.showinfo("Успех", "Точки успешно отправлены на ESP32 по Wi-Fi!")
        else:
            messagebox.showerror("Ошибка", f"Ошибка от ESP32: {response.status_code}")
    except Exception as e:
        messagebox.showerror("Ошибка", f"Не удалось подключиться к ESP32:\n{e}")


root = tk.Tk()
root.title("Рисование траектории")

canvas = tk.Canvas(root, width=600, height=400, bg='white')
canvas.pack(padx=10, pady=10)
canvas.bind("<Button-1>", on_canvas_click)

btn_frame = tk.Frame(root)
btn_frame.pack(pady=5)

send_btn = tk.Button(btn_frame, text="Отправить на ESP32", command=send_to_esp32)
send_btn.grid(row=0, column=0, padx=5)

clear_btn = tk.Button(btn_frame, text="Очистить", command=lambda: (canvas.delete("all"), points.clear()))
clear_btn.grid(row=0, column=1, padx=5)

root.mainloop()
