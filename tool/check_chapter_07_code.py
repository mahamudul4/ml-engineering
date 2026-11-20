"""Execute Chapter 7 code/solutions, numerical invariants and real workflow."""
import contextlib
import io
import json
import math
import os
from pathlib import Path
import runpy
import sys
import types
import unittest
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)
chapter = json.loads((ROOT/'assets/content/chapter_07.json').read_text(encoding='utf-8'))
assert [len(chapter[k]) for k in ['lessons','quizzes','interviews','exercises']] == [16,20,8,8]
scopes = {}
for lesson in chapter['lessons']:
    module = types.ModuleType(lesson['id'])
    sys.modules[lesson['id']] = module
    for block in lesson['blocks']:
        if block['type'] == 'code':
            with contextlib.redirect_stdout(io.StringIO()):
                exec(compile(block['body'],lesson['id'],'exec'), module.__dict__)
    scopes[lesson['id']] = module.__dict__
solutions = {}
for exercise in chapter['exercises']:
    compile(exercise['starter'],exercise['id'],'exec')
    output = io.StringIO(); scope = {}
    with contextlib.redirect_stdout(output): exec(exercise['solution'],scope)
    assert math.isclose(float(output.getvalue().strip()),exercise['expected'],abs_tol=1e-8), exercise['id']
    solutions[exercise['id']] = scope
np.testing.assert_allclose(scopes['ch07_gradients']['gradient'], [-7.,-13.])
experiment = scopes['ch07_workflow']
report = experiment['report']

class MathBehaviorTests(unittest.TestCase):
    def test_projection_invariants_and_invalid_input(self):
        project = solutions['ch07_ex_projection']['project']
        x = np.array([3.,2.])
        for u in [np.array([1.,0.]),np.array([-2.,0.]),np.array([1.,1.])]:
            p = project(x,u); r=x-p
            np.testing.assert_allclose(r@u,0.,atol=1e-12)
            np.testing.assert_allclose(x@x,p@p+r@r)
            np.testing.assert_allclose(project(p,u),p,atol=1e-12)
        with self.assertRaises(ValueError): project(x,[0.,0.])
        with self.assertRaises(ValueError): project(x,[[1.],[2.]])

    def test_gradient_has_same_objective_and_no_input_mutation(self):
        A=np.array([[1.,0.],[1.,1.],[1.,2.]])
        y=np.array([1.,2.,2.]); w=np.array([.2,-.4]); mask=np.array([0.,1.])
        before=w.copy(); original=A.copy()
        objective=experiment['objective_gradient']
        numeric=experiment['finite_difference'](A,y,w,mask,.1)
        loss,analytic=objective(A,y,w,mask,.1)
        np.testing.assert_allclose(analytic,numeric,rtol=1e-6,atol=1e-8)
        self.assertTrue(np.isfinite(loss))
        np.testing.assert_array_equal(w,before); np.testing.assert_array_equal(A,original)
        # The checker must detect a deliberately wrong factor of two.
        error=np.linalg.norm(2*analytic-numeric)/max(1.,np.linalg.norm(2*analytic),np.linalg.norm(numeric))
        self.assertGreater(error,.1)

    def test_shape_finiteness_and_penalty_errors(self):
        f=experiment['objective_gradient']; A=np.ones((3,2)); y=np.ones(3); w=np.zeros(2)
        with self.assertRaises(ValueError): f(A,y[:,None],w,[0,1],.1)
        with self.assertRaises(ValueError): f(A,y,w,[0,1],-.1)
        with self.assertRaises(ValueError): f(A,y,w,[0,-1],.1)
        with self.assertRaises(ValueError): f(A,y,[np.nan,0],[0,1],.1)
        with self.assertRaises(ValueError): experiment['finite_difference'](A,y,w,[0,1],.1,epsilon=0)

    def test_hessian_and_augmented_solution(self):
        A=np.array([[1.,0.],[1.,1.],[1.,2.]])
        y=np.array([1.,2.,2.]); mask=np.array([0.,1.]); alpha=.1
        H=A.T@A/len(y)+alpha*np.diag(mask)
        f=experiment['objective_gradient']; w=np.array([.3,.2]); h=1e-5
        for j in range(2):
            delta=np.eye(2)[j]*h
            numeric=(f(A,y,w+delta,mask,alpha)[1]-f(A,y,w-delta,mask,alpha)[1])/(2*h)
            np.testing.assert_allclose(numeric,H[:,j],rtol=1e-8,atol=1e-8)
        aug=np.vstack([A,np.diag(np.sqrt(len(y)*alpha*mask))])
        rhs=np.r_[y,np.zeros(2)]
        solved=np.linalg.lstsq(aug,rhs,rcond=None)[0]
        np.testing.assert_allclose(f(A,y,solved,mask,alpha)[1],0.,atol=1e-12)
        # Ridge stationarity generally has a non-orthogonal data residual.
        self.assertGreater(abs((A.T@(A@solved-y))[1]),.01)

    def test_quadratic_stability_and_spectral_reconstruction(self):
        angle=np.pi/6; c,s=np.cos(angle),np.sin(angle)
        R=np.array([[c,-s],[s,c]]); H=R@np.diag([1.,5.])@R.T
        w=np.array([3.,2.]); losses=[]
        for _ in range(20):
            losses.append(.5*w@H@w); w=w-.8/5*(H@w)
        self.assertTrue(np.all(np.diff(losses)<0))
        np.testing.assert_allclose(np.linalg.eigvalsh(H),[1.,5.])
        A=np.array([[1.,2.],[3.,4.],[1.,0.]])
        U,singular,Vt=np.linalg.svd(A,full_matrices=False)
        np.testing.assert_allclose((U*singular)@Vt,A,rtol=1e-12,atol=1e-12)

    def test_real_source_split_and_training_coordinates(self):
        self.assertEqual(report['rows'],32561)
        self.assertEqual((report['train_rows'],report['validation_rows']),(26050,6511))
        self.assertEqual(report['profile_key_excludes'],['hours_per_week','income'])
        groups=experiment['groups']; tr=experiment['train']; va=experiment['valid']
        self.assertTrue(set(groups[tr]).isdisjoint(groups[va]))
        np.testing.assert_allclose(experiment['mean'],experiment['X'][tr].mean(axis=0))
        np.testing.assert_allclose(experiment['A'][:,1:].mean(axis=0),0.,atol=1e-12)
        np.testing.assert_allclose(experiment['A_valid'][:,1:],
            (experiment['X'][va]-experiment['mean'])/experiment['scale'])

result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(MathBehaviorTests))
assert result.wasSuccessful()
assert report['gradient_relative_error']<1e-6
assert report['final_gradient_norm']<1e-7
assert report['theta_distance_to_reference']<1e-8
assert report['duplicate_rank']<report['duplicate_columns']
with contextlib.redirect_stdout(io.StringIO()):
    standalone=runpy.run_path(str(ROOT/'assets/datasets/adult/math_workflow.py'))
assert standalone['report']==report
(ROOT/'build/chapter-07-python-verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PASS: All lesson blocks, eight solutions, six behavior tests, real split/scaling, gradient checks and standalone agreement.')
