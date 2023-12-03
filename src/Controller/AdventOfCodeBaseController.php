<?php

namespace App\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

abstract class AdventOfCodeBaseController extends AbstractController
{
    abstract public function index(Request $request): Response;

    abstract public function getInput(): array;
}
