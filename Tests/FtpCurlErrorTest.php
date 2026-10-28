<?php

namespace Depage\Fs\Tests;

use Depage\Fs\Exceptions\FsException;
use Depage\Fs\Fs;
use Depage\Fs\Tests\TestClasses\FtpCurlTestClass;
use PHPUnit\Framework\TestCase;

class FtpCurlErrorTest extends TestCase
{
    // {{{ unreachableUrl
    /**
     * '.invalid' is reserved and can never resolve (RFC 6761), so cURL fails with
     * CURLE_COULDNT_RESOLVE_HOST (6). That is none of the errnos the wrapper
     * swallows as "not found" (9 and 21), so it has to report a hard error.
     *
     * Needs neither the ftp nor the ssh test server.
     */
    protected function unreachableUrl()
    {
        return 'ftp://' . $GLOBALS['REMOTE_USER'] . '@does-not-exist.invalid/Temp/';
    }
    // }}}
    // {{{ currentErrorHandler
    protected function currentErrorHandler()
    {
        $handler = set_error_handler(function () {});
        restore_error_handler();

        return $handler;
    }
    // }}}
    // {{{ tearDown
    protected function tearDown(): void
    {
        FtpCurlTestClass::disconnect();

        $this->assertTrue(stream_wrapper_restore('ftp'));
    }
    // }}}

    // {{{ testStreamWrapperThrowsFsException
    /**
     * Using the stream wrapper without Fs around it.
     */
    public function testStreamWrapperThrowsFsException()
    {
        FtpCurlTestClass::registerStream('ftp');

        $this->expectException(FsException::class);

        file_get_contents($this->unreachableUrl());
    }
    // }}}

    // {{{ testCurlErrorReportsCurlError
    /**
     * Regression: hard cURL errors used to be raised with
     * trigger_error(..., E_USER_ERROR). That aborted the script outright on
     * PHP < 8.4; on PHP >= 8.4 the deprecation notice for E_USER_ERROR came first,
     * so the FsException read "Passing E_USER_ERROR to trigger_error() is
     * deprecated..." instead of the actual cURL error.
     */
    public function testCurlErrorReportsCurlError()
    {
        $fs = Fs::factory($this->unreachableUrl());

        try {
            $fs->getString('testFile');
            $this->fail('Expected ' . FsException::class . ' for an unreachable host.');
        } catch (FsException $error) {
            $message = $error->getMessage();
        }

        $this->assertNotSame('', trim($message), 'Expected the cURL error message.');
        $this->assertStringNotContainsString('E_USER_ERROR', $message);
        $this->assertStringNotContainsString('deprecated', $message);
    }
    // }}}

    // {{{ testErrorHandlerAfterCurlError
    public function testErrorHandlerAfterCurlError()
    {
        $initialHandler = $this->currentErrorHandler();

        $fs = Fs::factory($this->unreachableUrl());

        try {
            $fs->getString('testFile');
        } catch (FsException $error) {
        }

        $this->assertSame($initialHandler, $this->currentErrorHandler());
    }
    // }}}
}

/* vim:set ft=php sw=4 sts=4 fdm=marker et : */
