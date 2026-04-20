<?php

function foo()
{
    print ('foo');

    while (true) {
        print ('foo');
        break;
    }

    do {
        print ('foo');
    } while (false);

    if (true) {
        print ('foo');
    } else {
        print ('foo');
    }

    for ($i = 0; $i < 5; $i++) {
        print ('foo');
    }
}
