<?php
header('Content-Type: text/event-stream');
header('Cache-Control: no-cache');
header('Connection: keep-alive');

$domain = escapeshellarg($_GET['domain']);
$email = escapeshellarg($_GET['email']);
$wildcard = ($_GET['wildcard'] === 'yes') ? 'yes' : 'no';

$cmd = "/bin/bash /path/to/your/script/setup_server.sh $domain $email $wildcard";

$descriptorspec = [
    1 => ['pipe', 'w'],  // stdout
    2 => ['pipe', 'w'],  // stderr
];

$process = proc_open($cmd, $descriptorspec, $pipes);

if (is_resource($process)) {
    while ($line = fgets($pipes[1])) {
        echo "data: " . trim($line) . "\n\n";
        ob_flush();
        flush();
    }
    while ($line = fgets($pipes[2])) {
        echo "data: ERROR: " . trim($line) . "\n\n";
        ob_flush();
        flush();
    }
    fclose($pipes[1]);
    fclose($pipes[2]);
    $return_value = proc_close($process);
    echo "data: Script execution completed with status $return_value\n\n";
    echo "data: EOF\n\n";
    ob_flush();
    flush();
} else {
    echo "data: Failed to start script\n\n";
    echo "data: EOF\n\n";
}
?>
