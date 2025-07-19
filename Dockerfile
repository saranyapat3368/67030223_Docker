# ใช้ Official ESP-IDF Docker Image เป็น Base Image
# Image นี้ประกอบด้วย ESP-IDF (เวอร์ชัน release-v5.4) และ Toolchain ที่จำเป็นซึ่งได้รับการติดตั้งไว้ล่วงหน้า
# การตรวจสอบ Tag ล่าสุดสามารถดำเนินการได้ที่: https://hub.docker.com/r/espressif/idf
# โดยการสำรวจส่วน "Tag summary" เพื่อการเลือกเวอร์ชันที่เหมาะสมและทันสมัยที่สุด
FROM espressif/idf:release-v5.4

# การตั้งค่า Environment Variable เพื่อให้กระบวนการติดตั้งแพ็กเกจเป็นแบบ Non-interactive พึงกระทำ
ENV DEBIAN_FRONTEND=noninteractive

# การติดตั้งแพ็กเกจเพิ่มเติมที่จำเป็น (โดยหลักคือ QEMU) พึงกระทำ
# qemu-system-misc: แพ็กเกจนี้มีความสำคัญอย่างยิ่ง เนื่องจากประกอบด้วย qemu-system-xtensa ซึ่งเป็นส่วนประกอบหลักที่ใช้สำหรับการจำลองการทำงานของชิป ESP32
# git: แม้ว่า Base Image บางรุ่นอาจรวม Git มาให้แล้ว แต่การระบุ Git ไว้ในรายการติดตั้งเพิ่มเติมจะช่วยให้มั่นใจได้ว่าเครื่องมือควบคุมเวอร์ชันนี้จะพร้อมใช้งานภายใน Container เสมอ ซึ่งจำเป็นสำหรับการจัดการโค้ด
RUN apt-get update && \
    apt-get install -y \
    qemu-system-misc \
    git && \
    rm -rf /var/lib/apt/lists/* # คำสั่งนี้ช่วยลดขนาดของ Docker Image โดยการลบไฟล์แพ็กเกจที่ดาวน์โหลดมาหลังจากติดตั้งเสร็จสิ้น

# การจัดตั้งผู้ใช้ที่มิใช่ root สำหรับวัตถุประสงค์ในการพัฒนาพึงกระทำ
# การสร้างผู้ใช้ที่ไม่ใช่ root เป็นแนวปฏิบัติที่ดีด้านความปลอดภัย เพื่อจำกัดสิทธิ์การเข้าถึงภายใน Container
ARG USERNAME=developer
ARG USER_UID=1001
# หากเกิดข้อผิดพลาดในระหว่างการสร้าง Image ซึ่งบ่งชี้ว่า GID/UID ซ้ำ การปรับค่า USER_UID ให้สูงขึ้น (เช่น 1002, 1003, ...) พึงกระทำ เพื่อหลีกเลี่ยงความขัดแย้งกับ Group ID หรือ User ID ที่มีอยู่แล้วใน Base Image
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME && \
    useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME && \
    usermod -aG sudo $USERNAME # การเพิ่มผู้ใช้เข้าในกลุ่ม 'sudo' จะช่วยให้ผู้ใช้สามารถดำเนินการคำสั่งที่ต้องใช้สิทธิ์ระดับสูงได้เมื่อจำเป็น

# การตรวจสอบเพื่อให้แน่ใจว่าโฟลเดอร์ home ของผู้ใช้ใหม่มีสิทธิ์ที่ถูกต้องพึงกระทำ
# คำสั่งนี้มีความสำคัญในการแก้ไขปัญหาด้านสิทธิ์การเข้าถึงที่อาจเกิดขึ้น หากโฟลเดอร์โฮมถูกสร้างโดยผู้ใช้ root ในเลเยอร์ก่อนหน้า
RUN chown -R $USERNAME:$USERNAME /home/$USERNAME

# การเพิ่มผู้ใช้ 'developer' เข้าในกลุ่ม dialout เพื่อการเข้าถึง Serial Port พึงกระทำ (ซึ่งมีความสำคัญสำหรับการ Flash แม้ว่าจะมิได้ใช้ในใบงานนี้)
# การเป็นสมาชิกของกลุ่ม 'dialout' เป็นสิ่งจำเป็นสำหรับการเข้าถึงอุปกรณ์ Serial Port บนระบบ Linux ซึ่งจำเป็นสำหรับการสื่อสารกับบอร์ด ESP32 จริงในอนาคต
RUN usermod -a -G dialout $USERNAME

# การเปลี่ยนไปใช้ผู้ใช้ที่ได้ถูกจัดตั้งขึ้นใหม่พึงกระทำ
USER $USERNAME

# เพิ่มคำสั่ง source export.sh ลงใน .bashrc ของผู้ใช้ เพื่อให้สภาพแวดล้อม ESP-IDF พร้อมใช้งานในทุก Terminal session
RUN echo ". /opt/esp/idf/export.sh" >> /home/$USERNAME/.bashrc

# การกำหนด Working Directory สำหรับโครงการพึงกระทำ
# การตั้งค่า Work Directory จะกำหนดโฟลเดอร์เริ่มต้นที่ผู้ใช้จะทำงานเมื่อเข้าสู่ Container
WORKDIR /home/$USERNAME/workspace
