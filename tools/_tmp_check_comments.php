<?php
$conn=new mysqli('localhost','root','','scholar_sys');
if($conn->connect_error){echo "connfail\n"; exit(1);} 
$res=$conn->query("SHOW TABLES LIKE 'announcement_comments'");
var_dump($res? $res->num_rows: null);
$r=$conn->query('SELECT COUNT(*) as c FROM announcement_comments');
var_dump($r? $r->fetch_assoc(): null);
$r2=$conn->query('SELECT * FROM announcement_comments');
while($row=$r2->fetch_assoc()){print_r($row);} 
?>
