<?php
$conn=new mysqli('localhost','root','','scholar_sys');
if($conn->connect_error){echo "connfail\n"; exit(1);} 
$res=$conn->query("SHOW TABLES LIKE 'announcements'");
if(!$res||$res->num_rows==0){echo "missing\n"; exit;}
$cols=$conn->query('SHOW COLUMNS FROM announcements');
while($row=$cols->fetch_assoc()){echo $row['Field']," ",$row['Type'],"\n";}
?>
